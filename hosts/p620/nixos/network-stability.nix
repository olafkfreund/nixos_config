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

  # AMD-specific TCP optimizations - using lib.mkMerge to avoid conflicts
  boot.kernel.sysctl = lib.mkMerge [
    # TCP settings optimized for AMD architecture
    {
      "net.ipv4.tcp_keepalive_time" = 600;
      "net.ipv4.tcp_keepalive_intvl" = 60;
      "net.ipv4.tcp_keepalive_probes" = 10;
      "net.ipv4.tcp_fin_timeout" = 30;
    }

    # BBR congestion control algorithm works well with AMD CPUs
    {
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_congestion_control" = "bbr";
    }

    # TCP tuning specific to AMD platforms
    {
      "net.ipv4.tcp_rmem" = "4096 1048576 16777216";
      "net.ipv4.tcp_wmem" = "4096 1048576 16777216";
    }
  ];

  # Instead of trying to configure electron-apps directly, we'll use environment settings
  # to provide the network stability enhancements for Electron applications
  environment = {
    # Electron configuration for network stability
    etc."electron-flags.conf" = {
      text = ''
        # Network stability enhancements for p620 host
        --disable-background-networking=false
        --force-fieldtrials="NetworkQualityEstimator/Enabled/"
        --enable-features=NetworkServiceInProcess
        --disable-gpu-process-crash-limit
        --network-service-in-process
      '';
      mode = "0644";
    };

    # Add environment variables for network stability
    sessionVariables = {
      DISABLE_REQUEST_THROTTLING = "1";
      ELECTRON_FORCE_WINDOW_MENU_BAR = "1";
      CHROME_NET_TCP_SOCKET_CONNECT_TIMEOUT_MS = "60000";
      CHROME_NET_TCP_SOCKET_CONNECT_ATTEMPT_DELAY_MS = "2000";
      ELECTRON_OZONE_PLATFORM_HINT = "auto"; # Let Electron choose the best platform
    };
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
