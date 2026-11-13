# Flux: connects this computer to the user's phone (Issue #2905), from the nixarchy-flux flake.
{ config, lib, pkgs, inputs, username, ... }:
let
  cfg = config.features.flux;
in
{
  imports = [ inputs.nixarchy-flux.nixosModules.default ];

  options.features.flux = {
    enable = lib.mkEnableOption "Flux, the phone connection";
    trustedConnections = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      description = ''
        NetworkManager connection UUIDs on which Flux may listen and announce itself.
        null installs no guard; a list (even empty) installs the nftables guard that
        blocks Flux ports and mDNS/12100 on every other interface except lo and tailscale0.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.flux = {
        enable = true;
        users = [ ];
        openFirewall = false;
        approve.services = [ ];
        webcam.enable = false;
      };

      # Hardening exception: fluxd is a user unit, so DynamicUser, ProtectHome and
      # ProtectSystem=strict do not apply (same reason as claude-swarm-reaper.nix:25-26).
      # No NoNewPrivileges either: fluxd runs the user's phone commands, which may use sudo.
      # No seccomp options (LockPersonality etc.): on a user unit they imply NoNewPrivileges (#2909).
      home-manager.users.${username} = {
        imports = [ inputs.nixarchy-flux.homeManagerModules.default ];
        services.flux = {
          enable = true;
          plugin.enable = true;
          browser.enable = false;
        };
      };
    }
    (lib.mkIf (cfg.trustedConnections != null) (
      let
        guardFile = pkgs.writeText "flux-guard.nft" ''
          table inet flux_guard
          delete table inet flux_guard
          table inet flux_guard {
            set trusted { type ifname; elements = { "lo", "tailscale0" } }
            chain input {
              type filter hook input priority filter - 1; policy accept;
              iifname @trusted accept
              ct state new tcp dport 12070-12108 drop
              ct state new udp dport 12100 drop
            }
            chain output {
              type filter hook output priority filter - 1; policy accept;
              oifname @trusted accept
              udp dport 5353 drop
              udp sport 5353 drop
              udp dport 12100 drop
            }
          }
        '';
        reconcileScript = pkgs.writeShellScript "flux-guard-reconcile" ''
          set -euo pipefail
          exec 9>/run/flux-guard.lock
          ${pkgs.util-linux}/bin/flock -x 9
          # (captured first, so a failed nmcli fails the unit instead of passing silently)
          active=$(${pkgs.networkmanager}/bin/nmcli -t -f UUID,DEVICE connection show --active)
          {
            printf 'flush set inet flux_guard trusted\n'
            printf 'add element inet flux_guard trusted { "lo", "tailscale0" }\n'
            while IFS=: read -r uuid device; do
              for trusted_uuid in ${lib.escapeShellArgs cfg.trustedConnections}; do
                if [[ $uuid == "$trusted_uuid" && $device =~ ^[a-zA-Z0-9_.:-]+$ ]]; then
                  printf 'add element inet flux_guard trusted { "%s" }\n' "$device"
                  break
                fi
              done
            done <<<"$active"
          } | ${pkgs.nftables}/bin/nft -f -
        '';
        hardening = {
          # Host network namespace CAP_NET_ADMIN requires a fixed root user, not DynamicUser.
          CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          ReadWritePaths = [ "/run" ];
          RestrictAddressFamilies = [ "AF_NETLINK" "AF_UNIX" ];
          ProtectKernelModules = true;
        };
      in
      {
        systemd.services.flux-guard = {
          wantedBy = [ "multi-user.target" ];
          upholds = [ "flux-guard-sync.service" ]; # (a manual restart brings the trust sync back too)
          before = [ "network-pre.target" ];
          wants = [ "network-pre.target" ];
          serviceConfig = hardening // {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.nftables}/bin/nft -f ${guardFile}";
            ExecReload = "${pkgs.nftables}/bin/nft -f ${guardFile}";
            ExecStop = "${pkgs.nftables}/bin/nft delete table inet flux_guard";
          };
        };

        systemd.services.flux-guard-sync = {
          wantedBy = [ "multi-user.target" ];
          after = [ "NetworkManager.service" "flux-guard.service" ];
          bindsTo = [ "flux-guard.service" ];
          unitConfig.ReloadPropagatedFrom = [ "flux-guard.service" ];
          serviceConfig = hardening // {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${reconcileScript}";
            ExecReload = "${reconcileScript}";
          };
        };

        networking.networkmanager.dispatcherScripts = [{
          type = "basic";
          source = pkgs.writeShellScript "flux-guard-dispatcher" ''
            case "$2" in
              up|down|dhcp4-change|connectivity-change) ${reconcileScript} ;;
            esac
          '';
        }];
      }
    ))
  ]);
}
