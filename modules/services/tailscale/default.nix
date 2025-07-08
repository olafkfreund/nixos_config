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

    preferredDERPs = mkOption {
      type = with types; listOf str;
      default = ["fra" "ams" "par" "lon"]; # Frankfurt, Amsterdam, Paris, London - for EU users
      description = "List of preferred DERP region codes";
      example = ["nyc" "chi" "sfo"]; # US-based regions
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
          # Add preferred DERP regions for better connection reliability
          "--advertise-routes="
          "--advertise-exit-node"
        ]
        ++ lib.optional (cfg.exitNode != null) "--exit-node=${cfg.exitNode}"
        ++ map (region: "--derp-region=${region}") cfg.preferredDERPs;
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
        # Add improved connection reliability options
        # Environment = "TS_DEBUG_DERP=all";
      };
    };

    # Service to ensure DNS setting is applied after tailscaled starts
    systemd.services.tailscale-dns-disable = mkIf (!cfg.acceptDns) {
      description = "Disable Tailscale DNS to prevent resolv.conf overwrite";
      after = ["tailscaled.service"];
      wants = ["tailscaled.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "disable-tailscale-dns" ''
          # Wait for tailscaled to be ready
          until ${pkgs.tailscale}/bin/tailscale status &>/dev/null; do
            echo "Waiting for tailscaled to be ready..."
            sleep 2
          done
          
          # Disable DNS to prevent resolv.conf overwrite
          echo "Disabling Tailscale DNS to preserve local DNS configuration..."
          ${pkgs.tailscale}/bin/tailscale set --accept-dns=false
          
          echo "Tailscale DNS disabled successfully"
        '';
        # Retry if tailscaled isn't ready yet
        Restart = "on-failure";
        RestartSec = "5s";
        StartLimitBurst = 10;
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

    # Service to restore resolv.conf if Tailscale overwrites it
    systemd.services.resolv-conf-protect = mkIf (!cfg.acceptDns) {
      description = "Protect resolv.conf from Tailscale overwrite";
      after = ["tailscaled.service"];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "5s";
        ExecStart = pkgs.writeShellScript "protect-resolv-conf" ''
          # Store original resolv.conf content
          EXPECTED_DNS="nameserver 192.168.1.222"
          
          while true; do
            # Check if resolv.conf contains Tailscale DNS
            if grep -q "100.100.100.100" /etc/resolv.conf 2>/dev/null; then
              echo "Tailscale overwrote resolv.conf, restoring local DNS..."
              
              # Restore proper DNS configuration
              echo "# Generated by NixOS Tailscale protection" > /etc/resolv.conf
              echo "nameserver 192.168.1.222" >> /etc/resolv.conf
              echo "nameserver 1.1.1.1" >> /etc/resolv.conf
              echo "nameserver 8.8.8.8" >> /etc/resolv.conf
              echo "search home.freundcloud.com" >> /etc/resolv.conf
              echo "options edns0" >> /etc/resolv.conf
              
              # Disable Tailscale DNS again
              ${pkgs.tailscale}/bin/tailscale set --accept-dns=false 2>/dev/null || true
              
              echo "DNS configuration restored"
            fi
            
            sleep 10
          done
        '';
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
