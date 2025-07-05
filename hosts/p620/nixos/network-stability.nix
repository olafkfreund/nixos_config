# Network stability configuration for p620
# Fixes net::ERR_NETWORK_CHANGED errors
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Enable the comprehensive network stability service with p620-specific settings
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

    # Helper service configuration
    helperService = {
      enable = true;
      startDelay = 2; # Quicker startup on this powerful machine
      restartSec = 15; # Faster restart on failure for this host
    };

    # Use the script from the standard location
    scriptPath = ../../../scripts/network-stability-helper.sh;
  };

  # AMD-specific TCP optimizations (simplified from mkMerge pattern)
  boot.kernel.sysctl = {
    # TCP settings optimized for AMD architecture
    "net.ipv4.tcp_keepalive_time" = 600;
    "net.ipv4.tcp_keepalive_intvl" = 60;
    "net.ipv4.tcp_keepalive_probes" = 10;
    "net.ipv4.tcp_fin_timeout" = 30;
    # BBR congestion control algorithm works well with AMD CPUs
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
    # TCP tuning specific to AMD platforms
    "net.ipv4.tcp_rmem" = "4096 1048576 16777216";
    "net.ipv4.tcp_wmem" = "4096 1048576 16777216";
  };

  # Additional Electron app improvements specific to p620
  environment = {
    # Add p620-specific flags to the electron flags config
    etc."electron-flags.conf".text = lib.mkAfter ''
      # P620-specific network optimizations
      --disable-gpu-process-crash-limit
      --network-service-in-process
    '';

    # Add environment variables specific to this hardware using mkForce
    # to ensure they override the default values
    sessionVariables = {
      # Use higher timeouts for better stability on this hardware
      CHROME_NET_TCP_SOCKET_CONNECT_TIMEOUT_MS = lib.mkForce "90000"; # Longer timeout for this host
    };
  };

  # Network wait is now handled by the consolidated service in network-stability module
}
