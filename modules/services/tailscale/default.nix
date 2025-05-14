{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.vpn.tailscale;
in {
  options.vpn.tailscale = {
    enable = mkEnableOption "Tailscale VPN service";

    acceptDns = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to accept DNS settings from Tailscale";
      example = false;
    };

    netfilterMode = mkOption {
      type = types.enum ["on" "off"];
      default = "off";
      description = "Netfilter mode for Tailscale routing";
      example = "off";
    };

    exitNode = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Hostname of exit node to use for internet traffic";
      example = "exit-node.example.com";
    };
  };

  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;

      # Use a more stable routing approach
      useRoutingFeatures = "both";

      # Automatically reconnect and authenticate
      authKeyFile = null; # Set this to a file containing your auth key for unattended setup

      # Make tailscaled wait for the network to be available with safer defaults
      extraUpFlags =
        [
          "--accept-dns=${
            if cfg.acceptDns
            then "true"
            else "false"
          }"
          "--shields-up=false"
          "--netfilter-mode=${cfg.netfilterMode}"
        ]
        ++ lib.optional (cfg.exitNode != null) "--exit-node=${cfg.exitNode}";
    };

    # Enable IP forwarding for tailscale subnet routing
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
      # Add TCP/IP stack tuning for better VPN performance
      "net.core.rmem_max" = 2500000;
      "net.core.wmem_max" = 2500000;
    };

    # Configure systemd service ordering to ensure proper DNS handling
    systemd.services.tailscaled = {
      after = ["network.target" "NetworkManager.service" "systemd-resolved.service"];
      wants = ["network.target"];
      # Wait until network is really online to avoid DNS issues
      requires = ["network-online.target"];
      # Add restart configuration to improve reliability
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };

    # Delay tailscale startup to ensure network stability
    systemd.services.tailscale-delay = {
      description = "Delay Tailscale startup for network stability";
      before = ["tailscaled.service"];
      requiredBy = ["tailscaled.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/sleep 3";
        RemainAfterExit = true;
      };
      wantedBy = ["multi-user.target"];
    };

    # Allow tailscale through firewall with reliable configuration
    networking.firewall = {
      trustedInterfaces = ["tailscale0"];
      allowedUDPPorts = [41641]; # Tailscale UDP port
      checkReversePath = "loose"; # Important for Tailscale to work properly
      # Add persistent keepalive for better NAT traversal
      extraCommands = ''
        ${pkgs.iproute2}/bin/ip link set dev tailscale0 mtu 1420 || true
      '';
    };

    environment.systemPackages = [
      pkgs.trayscale
      pkgs.ktailctl
      pkgs.tailscale
    ];
  };
}
