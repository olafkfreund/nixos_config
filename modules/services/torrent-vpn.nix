# Transmission confined to a ProtonVPN WireGuard network namespace.
#
# Peer traffic leaves exclusively through the tunnel. The kill switch is
# structural rather than a firewall rule: the namespace has no route to the
# internet except wg-proton, so a dead tunnel means dead torrents instead of
# leaked ones. Everything else on the host — Plex, NFS, Tailscale, cloudflared,
# NZBGet, SABnzbd — keeps using the normal route and is untouched.
#
#   root namespace                     torrent namespace
#   ──────────────                     ─────────────────
#   eno1 ── internet                   wg-proton ── default route (VPN only)
#   :9091 socket-proxy ───── veth ───→ transmission RPC
#
# The RPC proxy is what keeps this a drop-in change: cloudflared, the *arr
# download-client settings, audiobookbay-automated, and LAN/tailnet clients all
# keep talking to the same host:9091 they did before.
#
# Only the plaintext interface is moved into the namespace; the encrypted UDP
# socket stays in the root namespace and uses the host's ordinary route.
# See https://www.wireguard.com/netns/.
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.features.torrentVpn;

  ns = "tvpn";
  iface = "wg-proton";

  # Link-scope /30 between namespace and host, carrying RPC only. It is
  # deliberately never made a default route, so it cannot carry peer traffic
  # even if the tunnel is down.
  hostIp = "10.77.0.1";
  nsIp = "10.77.0.2";

  rpcPort = config.services.transmission.settings.rpc-port;
  ip = "${pkgs.iproute2}/bin/ip";
in
{
  options.features.torrentVpn = {
    enable = lib.mkEnableOption "Transmission confined to a ProtonVPN WireGuard namespace";

    address = lib.mkOption {
      type = lib.types.str;
      example = "10.2.0.2/32";
      description = ''
        The `Address` field of the ProtonVPN WireGuard config. Unique to the
        downloaded config; not secret.
      '';
    };

    gateway = lib.mkOption {
      type = lib.types.str;
      default = "10.2.0.1";
      description = ''
        Tunnel gateway, which is also the `DNS` field of the ProtonVPN config
        and its NAT-PMP responder. Name resolution inside the namespace must go
        through here — the host's stub resolver is not reachable from it.
      '';
    };

    privateKeyFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Runtime path to a file holding the `PrivateKey` of the ProtonVPN
        config, and nothing else. Read at service start, never at evaluation.
      '';
    };

    peer = {
      publicKey = lib.mkOption {
        type = lib.types.str;
        description = "The `PublicKey` of the ProtonVPN config's `[Peer]` section.";
      };

      endpoint = lib.mkOption {
        type = lib.types.str;
        example = "185.159.157.1:51820";
        description = "The `Endpoint` of the ProtonVPN config's `[Peer]` section.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.transmission.enable;
        message = "features.torrentVpn confines services.transmission, which is not enabled.";
      }
      # Unset peer details would build cleanly and then fail to hand off any
      # traffic at runtime, so refuse them here instead.
      {
        assertion = cfg.peer.publicKey != "";
        message = "features.torrentVpn.peer.publicKey is unset — copy PublicKey from the ProtonVPN WireGuard config.";
      }
      {
        assertion = cfg.peer.endpoint != "";
        message = "features.torrentVpn.peer.endpoint is unset — copy Endpoint from the ProtonVPN WireGuard config.";
      }
    ];

    # `ip netns exec` maps /etc/netns/<ns>/ over /etc/, but systemd's
    # NetworkNamespacePath= does not — the transmission unit re-does this
    # binding by hand below.
    environment.etc."netns/${ns}/resolv.conf".text = "nameserver ${cfg.gateway}\n";

    services.transmission.settings = {
      # Requests now arrive from the host side of the veth rather than directly
      # from the LAN. Reachability is unchanged — the proxy below listens where
      # transmission used to, and rpc-authentication still applies.
      rpc-whitelist = lib.mkForce "127.0.0.1,${hostIp}";
    };

    networking.wireguard.interfaces.${iface} = {
      privateKeyFile = toString cfg.privateKeyFile;
      ips = [ cfg.address ];
      interfaceNamespace = ns;

      # The module's generated route is "default dev wg-proton" with no next
      # hop, which leaves Proton's NAT-PMP responder undiscoverable and so
      # kills port forwarding. Add the equivalent route with an explicit
      # gateway instead.
      allowedIPsAsRoutes = false;
      postSetup = ''
        ${ip} -n ${ns} route add ${cfg.gateway}/32 dev ${iface}
        ${ip} -n ${ns} route add default via ${cfg.gateway} dev ${iface}
      '';

      peers = [
        {
          inherit (cfg.peer) publicKey endpoint;
          allowedIPs = [ "0.0.0.0/0" ];
          persistentKeepalive = 25;
        }
      ];
    };

    systemd = {
      sockets.transmission-rpc-proxy = {
        description = "Transmission RPC, host side of the torrent namespace";
        wantedBy = [ "sockets.target" ];
        socketConfig.ListenStream = toString rpcPort;
      };

      services = {
        torrent-netns = {
          description = "Network namespace for VPN-confined torrent traffic";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = pkgs.writeShellScript "torrent-netns-up" ''
              set -eu
              ${ip} netns add ${ns}
              ${ip} -n ${ns} link set lo up
              ${ip} link add ${ns}-host type veth peer name ${ns}-ns netns ${ns}
              ${ip} addr add ${hostIp}/30 dev ${ns}-host
              ${ip} link set ${ns}-host up
              ${ip} -n ${ns} addr add ${nsIp}/30 dev ${ns}-ns
              ${ip} -n ${ns} link set ${ns}-ns up
            '';
            ExecStop = pkgs.writeShellScript "torrent-netns-down" ''
              ${ip} link del ${ns}-host || true
              ${ip} netns del ${ns} || true
            '';
          };
        };

        "wireguard-${iface}" = {
          bindsTo = [ "torrent-netns.service" ];
          after = [ "torrent-netns.service" ];
        };

        transmission = {
          bindsTo = [ "torrent-netns.service" "wireguard-${iface}.service" ];
          after = [ "torrent-netns.service" "wireguard-${iface}.service" ];
          serviceConfig = {
            NetworkNamespacePath = "/var/run/netns/${ns}";
            # Overlays the host resolv.conf the module already binds in as part
            # of /etc; without it the daemon inherits a stub resolver address
            # that answers nothing inside the namespace.
            BindReadOnlyPaths = [ "/etc/netns/${ns}/resolv.conf:/etc/resolv.conf" ];
            # Joining a pre-existing network namespace needs privileges the
            # module's default private user namespace does not carry.
            PrivateUsers = false;
          };
        };

        transmission-rpc-proxy = {
          description = "Proxy Transmission RPC into the torrent namespace";
          requires = [ "transmission-rpc-proxy.socket" ];
          after = [ "transmission-rpc-proxy.socket" "transmission.service" ];
          serviceConfig = {
            ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd ${nsIp}:${toString rpcPort}";
            DynamicUser = true;
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateDevices = true;
            RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
          };
        };
      };
    };

    # Leak check: the two addresses must differ, and the namespace default
    # route must point at the tunnel. Needs root for `ip netns exec`.
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "torrent-vpn-check" ''
        set -eu
        echo "host exit IP  : $(${pkgs.curl}/bin/curl -s --max-time 10 https://api.ipify.org)"
        echo "tunnel exit IP: $(${ip} netns exec ${ns} ${pkgs.curl}/bin/curl -s --max-time 10 https://api.ipify.org)"
        echo
        echo "namespace routes:"
        ${ip} -n ${ns} route
      '')
    ];
  };
}
