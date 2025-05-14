# Example configuration for fixing net::ERR_NETWORK_CHANGED error
# Import this file in your host configuration
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Enable the comprehensive network stability service
  services.network-stability = {
    enable = true;

    # Configure monitoring (optional adjustments)
    monitoring = {
      enable = true;
      interval = 30; # Check every 30 seconds
    };

    # Configure secure DNS
    secureDns = {
      enable = true;
      providers = [
        "1.1.1.1#cloudflare-dns.com"
        "8.8.8.8#dns.google"
        "9.9.9.9#dns.quad9.net"
      ];
    };

    # Configure Tailscale integration
    tailscale = {
      enhance = true;
      acceptDns = false; # Don't let Tailscale manage DNS
    };

    # Improve Electron apps
    electron = {
      improve = true;
    };

    # Configure connection stability
    connectionStability = {
      enable = true;
      switchDelayMs = 5000; # 5 second delay before switching networks
    };
  };

  # Additional TCP/IP tuning for better network stability
  boot.kernel.sysctl = {
    # Keep existing sysctl values

    # Additional TCP settings for better connection resilience
    "net.ipv4.tcp_keepalive_time" = 600;
    "net.ipv4.tcp_keepalive_intvl" = 60;
    "net.ipv4.tcp_keepalive_probes" = 10;

    # Avoid connection timeouts
    "net.ipv4.tcp_fin_timeout" = 30;

    # Better TCP congestion control
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  # Configure electron-apps system module for better network handling
  electron-apps = {
    enable = true;
    networkStability = true;
  };

  # Enable wayland-environment for better Electron app integration
  wayland-environment.enable = true;

  # Disable NetworkManager wait-online services for faster boots
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;
}
