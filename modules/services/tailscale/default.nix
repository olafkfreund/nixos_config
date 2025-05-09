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
    enable = mkEnableOption {
      default = true;
      description = "Enable Tailscale";
    };
  };
  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;

      # Fixes DNS issues by using a consistent approach for DNS configuration
      useRoutingFeatures = "both";

      # Automatically reconnect and authenticate
      authKeyFile = null; # Set this to a file containing your auth key for unattended setup

      # Make tailscaled wait for the network to be available
      extraUpFlags = [
        "--accept-dns=true"
        "--shields-up=false"
      ];
    };

    # Enable IP forwarding for tailscale subnet routing
    boot.kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };

    # Configure systemd service ordering to ensure proper DNS handling
    systemd.services.tailscaled = {
      after = ["network.target" "NetworkManager.service" "systemd-resolved.service"];
      wants = ["network.target"];
      # Wait until network is really online to avoid DNS issues
      requires = ["network-online.target"];
    };

    # Allow tailscale through firewall
    networking.firewall = {
      trustedInterfaces = ["tailscale0"];
      allowedUDPPorts = [41641]; # Tailscale UDP port
      checkReversePath = "loose"; # Important for Tailscale to work properly
    };

    environment.systemPackages = [
      pkgs.trayscale
      pkgs.ktailctl
      pkgs.tailscale
    ];
  };
}
