{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.services.network-stability;
in
{
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
        example = [ "9.9.9.9#dns.quad9.net" ];
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

    # Add helper service configuration options
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

      restartSec = mkOption {
        type = types.int;
        default = 30;
        description = "Time in seconds to wait before restarting the service on failure";
        example = 60;
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

    # Enable secure DNS if configured - using mkDefault to allow host override
    services.secure-dns = mkIf cfg.secureDns.enable {
      enable = mkDefault true; # Use mkDefault to allow the host to override this
      dnssec = mkDefault "true";
      fallbackProviders = cfg.secureDns.providers;
      useStubResolver = true;
    };

    # Enable network monitoring if configured
    services.network-monitoring = mkIf cfg.monitoring.enable {
      enable = true;
      monitorIntervalSeconds = cfg.monitoring.interval;
    };

    # Consolidated DNS monitoring service
    systemd.services.network-dns-monitor = mkIf cfg.monitoring.enable {
      description = "Network DNS resolution monitoring and recovery";
      after = [ "network-online.target" "systemd-resolved.service" ];
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = pkgs.writeShellScript "network-dns-monitor" ''
          #!/bin/sh
          # Consolidated DNS monitoring from network-monitoring and secure-dns modules
          while true; do
            dns_failed=0

            # Check multiple domains for robustness
            for domain in "cloudflare.com" "google.com" "nixos.org"; do
              if ! ${pkgs.inetutils}/bin/host -W 2 "$domain" >/dev/null 2>&1; then
                echo "DNS resolution failed for $domain" | ${pkgs.systemd}/bin/systemd-cat -t network-dns-monitor -p warning
                dns_failed=1
              fi
            done

            # If any DNS check failed, restart systemd-resolved
            if [ "$dns_failed" -eq 1 ]; then
              echo "Restarting systemd-resolved due to DNS failures" | ${pkgs.systemd}/bin/systemd-cat -t network-dns-monitor -p warning
              ${pkgs.systemd}/bin/systemctl restart systemd-resolved.service
              sleep 10
            fi

            sleep ${toString cfg.monitoring.interval}
          done
        '';
        Restart = "on-failure";
        RestartSec = "30s";
      };
    };

    # Environment configuration for network stability
    environment = mkMerge [
      # Electron network stability improvements
      (mkIf cfg.electron.improve {
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

        # Add environment variables for network stability with mkDefault
        # to allow host-specific overrides
        sessionVariables = {
          DISABLE_REQUEST_THROTTLING = mkDefault "1";
          CHROME_NET_TCP_SOCKET_CONNECT_TIMEOUT_MS = mkDefault "60000";
          CHROME_NET_TCP_SOCKET_CONNECT_ATTEMPT_DELAY_MS = mkDefault "2000";
        };
      })

      # Network stability helper script
      (mkIf cfg.helperService.enable {
        systemPackages = [
          (pkgs.writeShellScriptBin "network-stability-helper" (builtins.readFile (toString cfg.scriptPath)))
        ];
      })
    ];

    # Network stability sysctl settings (simplified from mkMerge pattern)
    boot.kernel.sysctl = {
      # TCP connection handling improvements
      "net.ipv4.tcp_slow_start_after_idle" = 0;
      "net.ipv4.tcp_fastopen" = 3;
      # More stable IPv4 networking
      "net.ipv4.route.gc_timeout" = 300;
      # Network buffer size improvements
      "net.core.rmem_max" = 16777216;
      "net.core.wmem_max" = 16777216;
      "net.core.rmem_default" = 1048576;
      "net.core.wmem_default" = 1048576;
    };

    # Network stability helper service (merged from network-stability-service.nix)
    systemd.services.network-stability-helper = mkIf cfg.helperService.enable (
      let
        stabilityScript = pkgs.writeShellScriptBin "network-stability-helper" (builtins.readFile (toString cfg.scriptPath));
      in
      {
        description = "Network Stability Helper Service";
        documentation = [ "https://github.com/olafkfreund/nixos-config/blob/main/doc/network-stability-guide.md" ];
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" "NetworkManager.service" "systemd-networkd.service" ];

        path = with pkgs; [
          iproute2
          inetutils
          systemd
          coreutils
          gnugrep
        ];

        serviceConfig = {
          Type = "simple";
          ExecStartPre = "${pkgs.coreutils}/bin/sleep ${toString cfg.helperService.startDelay}";
          ExecStart = "${stabilityScript}/bin/network-stability-helper";
          Restart = "on-failure";
          RestartSec = "${toString cfg.helperService.restartSec}";

          # Security hardening
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;

          # Resource limits
          LimitNOFILE = 1024;
          CPUSchedulingPolicy = "idle";
          MemoryHigh = "100M";
          MemoryMax = "150M";
        };
      }
    );

    # Create sync point for network stability events
    systemd.tmpfiles.rules = mkIf cfg.helperService.enable [
      "d /run/network-stability 0755 root root -"
      "f /run/network-stability-event 0644 root root -"
    ];

    # Consolidated network wait service (replaces separate wait services)
    systemd.services.network-stability-wait = {
      description = "Wait for network hardware and stability";
      before = [ "network-online.target" "NetworkManager.service" "systemd-networkd.service" ];
      wantedBy = [ "network-online.target" "NetworkManager.service" "systemd-networkd.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/sleep 3";
        RemainAfterExit = true;
      };
    };

    # Validation and error handling (conditional to avoid evaluation issues)
    assertions = mkIf cfg.enable [
      {
        assertion = cfg.monitoring.interval > 0 && cfg.monitoring.interval <= 300;
        message = "Network monitoring interval must be between 1 and 300 seconds";
      }
      {
        assertion = cfg.connectionStability.switchDelayMs >= 1000;
        message = "Connection stability switch delay must be at least 1000ms to prevent network thrashing";
      }
      {
        assertion = cfg.helperService.startDelay >= 0 && cfg.helperService.startDelay <= 60;
        message = "Helper service start delay must be between 0 and 60 seconds";
      }
      {
        assertion = !cfg.secureDns.enable || cfg.secureDns.providers != [ ];
        message = "At least one DNS provider must be specified when secure DNS is enabled";
      }
    ];

    warnings = [
      (mkIf (cfg.monitoring.interval < 10) ''
        Network monitoring interval of ${toString cfg.monitoring.interval} seconds is very aggressive.
        This may cause excessive system load. Consider using 10 seconds or more.
      '')
      (mkIf (cfg.connectionStability.switchDelayMs < 3000) ''
        Connection stability switch delay of ${toString cfg.connectionStability.switchDelayMs}ms is quite short.
        This may cause rapid network switching. Consider 3000ms or higher for better stability.
      '')
      (mkIf (cfg.secureDns.enable && !cfg.monitoring.enable) ''
        Secure DNS is enabled but network monitoring is disabled.
        Consider enabling monitoring to detect DNS issues automatically.
      '')
    ];
  };
}
