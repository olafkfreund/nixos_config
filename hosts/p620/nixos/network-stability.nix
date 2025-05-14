# Network stability configuration for p620
# Fixes net::ERR_NETWORK_CHANGED errors
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Enable the comprehensive network stability service
  services.network-stability = {
    enable = true;

    # Configure monitoring with shorter intervals for this host
    monitoring = {
      enable = true;
      interval = 20; # Check every 20 seconds
    };

    # Configure secure DNS with Cloudflare, Google, and Quad9 for redundancy
    secureDns = {
      enable = true;
      providers = [
        "1.1.1.1#cloudflare-dns.com"
        "8.8.8.8#dns.google"
        "9.9.9.9#dns.quad9.net"
      ];
    };

    # Configure Tailscale with conservative settings for stability
    tailscale = {
      enhance = true;
      acceptDns = false; # Don't let Tailscale manage DNS to avoid conflicts
    };

    # Improve Electron apps
    electron = {
      improve = true;
    };

    # Configure connection stability with longer delay for p620
    connectionStability = {
      enable = true;
      switchDelayMs = 7000; # 7 second delay before switching networks
    };
  };

  # AMD-specific network optimizations
  boot.kernel.sysctl = {
    # TCP settings optimized for AMD architecture
    "net.ipv4.tcp_keepalive_time" = 600;
    "net.ipv4.tcp_keepalive_intvl" = 60;
    "net.ipv4.tcp_keepalive_probes" = 10;
    "net.ipv4.tcp_fin_timeout" = 30;

    # BBR congestion control algorithm works well with AMD CPUs
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";

    # Increase network buffer sizes for better stability
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.core.rmem_default" = 1048576;
    "net.core.wmem_default" = 1048576;
    "net.ipv4.tcp_rmem" = "4096 1048576 16777216";
    "net.ipv4.tcp_wmem" = "4096 1048576 16777216";
  };

  # Configure electron-apps for this host
  electron-apps = {
    enable = true;
    networkStability = true;
  };

  # Short sleep before network services to ensure hardware is ready
  systemd.services.network-hardware-wait = {
    description = "Wait for network hardware initialization";
    before = ["NetworkManager.service" "systemd-networkd.service"];
    wantedBy = ["NetworkManager.service" "systemd-networkd.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/sleep 2";
      RemainAfterExit = true;
    };
  };
}
