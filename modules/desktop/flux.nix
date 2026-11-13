# Flux: connects this computer to the user's phone (Issue #2905), from the nixarchy-flux flake.
{ config, lib, inputs, username, ... }:
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
      home-manager.users.${username} = {
        imports = [ inputs.nixarchy-flux.homeManagerModules.default ];
        services.flux = {
          enable = true;
          plugin.enable = true;
          browser.enable = false;
        };
        systemd.user.services.fluxd.Service.LockPersonality = true;
      };
    }
    (lib.mkIf (cfg.trustedConnections != null) {
      # Step 4 (the guard) fills this.
    })
  ]);
}
