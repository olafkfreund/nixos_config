{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.network-stability;
in {
  options.services.network-stability = {
    enable = mkEnableOption "Comprehensive network stability improvements";

    monitoring = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable network monitoring";
        example = false;
      };

      interval = mkOption {
        type = types.int;
        default = 30;
        description = "Monitoring interval in seconds";
        example = 60;
      };
    };

    secureDns = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable secure DNS configuration";
        example = false;
      };

      providers = mkOption {
        type = types.listOf types.str;
        default = [
          "1.1.1.1#cloudflare-dns.com"
          "8.8.8.8#dns.google"
        ];
        description = "List of DNS providers to use";
        example = ["9.9.9.9#dns.quad9.net"];
      };
    };

    tailscale = {
      enhance = mkOption {
        type = types.bool;
        default = true;
        description = "Enable enhanced Tailscale configuration";
        example = false;
      };

      acceptDns = mkOption {
        type = types.bool;
        default = false;
        description = "Whether Tailscale should manage DNS";
        example = true;
      };
    };

    electron = {
      improve = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Electron app network stability improvements";
        example = false;
      };
    };

    connectionStability = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable network connection stability enhancements";
        example = false;
      };

      switchDelayMs = mkOption {
        type = types.int;
        default = 5000;
        description = "Delay in milliseconds before switching network interfaces";
        example = 3000;
      };
    };

    # Add helper service configuration options (new)
    helperService = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable the network stability helper service";
        example = false;
      };

      startDelay = mkOption {
        type = types.int;
        default = 5;
        description = "Delay in seconds before starting the network stability service";
        example = 10;
      };
    };

    # Script path option required by network-stability-service.nix
    scriptPath = mkOption {
      type = types.path;
      default = ../../../scripts/network-stability-helper.sh;
      description = "Path to the network stability helper script";
      example = "/path/to/network-stability-helper.sh";
    };
  };

  config = mkIf cfg.enable {
    # Enable network stability features
    networking.stableConnection = {
      enable = cfg.connectionStability.enable;
      interfaceSwitchDelayMs = cfg.connectionStability.switchDelayMs;
    };

    # Enable secure DNS if configured
    services.secure-dns = mkIf cfg.secureDns.enable {
      enable = true;
      dnssec = "true";
      fallbackProviders = cfg.secureDns.providers;
      useStubResolver = true;
    };

    # Enable network monitoring if configured
    services.network-monitoring = mkIf cfg.monitoring.enable {
      enable = true;
      monitorIntervalSeconds = cfg.monitoring.interval;
    };

    # Enable enhanced Tailscale configuration if configured and available
    vpn.tailscale = mkIf (cfg.tailscale.enhance && hasAttrByPath ["vpn" "tailscale" "enable"] config && config.vpn.tailscale.enable) {
      acceptDns = cfg.tailscale.acceptDns;
      netfilterMode = "off";
    };

    # Add Electron network stability improvements directly through environment
    environment = mkIf cfg.electron.improve {
      # Create a global flags configuration file for Electron network stability
      etc = {
        "electron-flags.conf" = {
          text = ''
            # Network stability settings
            --disable-background-networking=false
            --force-fieldtrials="NetworkQualityEstimator/Enabled/"
            --enable-features=NetworkServiceInProcess
          '';
          mode = "0644";
        };
      };

      # Add environment variables for network stability
      sessionVariables = {
        DISABLE_REQUEST_THROTTLING = "1";
        CHROME_NET_TCP_SOCKET_CONNECT_TIMEOUT_MS = "60000";
        CHROME_NET_TCP_SOCKET_CONNECT_ATTEMPT_DELAY_MS = "2000";
      };
    };

    # Properly merge sysctl settings with existing ones instead of potentially overriding them
    boot.kernel.sysctl = mkMerge [
      # TCP connection handling improvements
      {
        "net.ipv4.tcp_slow_start_after_idle" = 0;
        "net.ipv4.tcp_fastopen" = 3;
      }

      # More stable IPv4 networking
      {
        "net.ipv4.route.gc_timeout" = 300;
      }

      # Network buffer size improvements
      {
        "net.core.rmem_max" = 16777216;
        "net.core.wmem_max" = 16777216;
        "net.core.rmem_default" = 1048576;
        "net.core.wmem_default" = 1048576;
      }
    ];

    # Enable the network stability helper service if requested
    systemd.services.network-stability-helper.enable = cfg.helperService.enable;

    # Configure startDelay for the helper service
    services.network-stability.startDelay = cfg.helperService.startDelay;

    # Ensure the system waits for stable network before starting key services
    systemd.services.network-stability-wait = {
      description = "Wait for network stability";
      before = ["network-online.target"];
      wantedBy = ["network-online.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/sleep 3";
        RemainAfterExit = true;
      };
    };
  };
}
