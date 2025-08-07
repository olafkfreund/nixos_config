{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.network-monitoring;
in {
  options.services.network-monitoring = {
    enable = mkEnableOption "Network stability monitoring";

    logDir = mkOption {
      type = types.str;
      default = "/var/log/network-monitoring";
      description = "Directory to store network monitoring logs";
      example = "/var/log/network-stability";
    };

    monitorIntervalSeconds = mkOption {
      type = types.int;
      default = 10;
      description = "Interval in seconds between network checks";
      example = 30;
    };
  };

  config = mkIf cfg.enable {
    # Create the monitoring script with configured parameters
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "network-monitor" ''
        #!/usr/bin/env bash
        # Network stability monitoring script
        # This script monitors network interfaces and connection stability
        # to help diagnose issues like "net::ERR_NETWORK_CHANGED" errors

        # Set up logging
        LOG_DIR="${cfg.logDir}"
        LOG_FILE="$LOG_DIR/network-monitor.log"
        MAX_LOG_SIZE_MB=10

        # Ensure log directory exists
        mkdir -p "$LOG_DIR"

        # Function to log with timestamps
        log() {
          echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
        }

        # Function to rotate logs if they get too large
        rotate_logs() {
          local size_in_bytes=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
          local size_in_mb=$((size_in_bytes / 1048576))

          if [ "$size_in_mb" -gt "$MAX_LOG_SIZE_MB" ]; then
            mv "$LOG_FILE" "$LOG_FILE.old"
            log "Log file rotated due to size ($size_in_mb MB)"
          fi
        }

        # DNS monitoring is now handled by network-stability module
        # to provide centralized monitoring and recovery

        # Get current network information
        get_network_info() {
          log "--- Network Interfaces ---"
          ${pkgs.iproute2}/bin/ip -brief addr show | grep -v "^lo" | while read line; do
            log "$line"
          done

          log "--- Default Routes ---"
          ${pkgs.iproute2}/bin/ip route show default | while read line; do
            log "$line"
          done

          log "--- DNS Servers ---"
          ${pkgs.gnugrep}/bin/grep nameserver /etc/resolv.conf | while read line; do
            log "$line"
          done

          # Check for systemd-resolved
          if ${pkgs.systemd}/bin/systemctl is-active systemd-resolved >/dev/null 2>&1; then
            log "--- systemd-resolved Status ---"
            ${pkgs.systemd}/bin/resolvectl status | ${pkgs.gnugrep}/bin/grep "DNS Server" | while read line; do
              log "$line"
            done
          fi
        }

        # Monitor network changes
        monitor_network() {
          log "Starting network stability monitor"
          get_network_info

          # Store initial interface and route info
          local prev_interfaces=$(${pkgs.iproute2}/bin/ip -brief addr show | grep -v "^lo" | sort)
          local prev_routes=$(${pkgs.iproute2}/bin/ip route show default | sort)

          while true; do
            # Check for interface changes
            local current_interfaces=$(${pkgs.iproute2}/bin/ip -brief addr show | grep -v "^lo" | sort)
            if [[ "$current_interfaces" != "$prev_interfaces" ]]; then
              log "Network interface change detected:"
              log "Before:"
              echo "$prev_interfaces" | while read line; do log "  $line"; done
              log "After:"
              echo "$current_interfaces" | while read line; do log "  $line"; done
              prev_interfaces="$current_interfaces"
            fi

            # Check for route changes
            local current_routes=$(${pkgs.iproute2}/bin/ip route show default | sort)
            if [[ "$current_routes" != "$prev_routes" ]]; then
              log "Default route change detected:"
              log "Before:"
              echo "$prev_routes" | while read line; do log "  $line"; done
              log "After:"
              echo "$current_routes" | while read line; do log "  $line"; done
              prev_routes="$current_routes"
            fi

            # DNS monitoring moved to network-stability module

            # Rotate logs if needed
            rotate_logs

            # Wait before checking again
            sleep ${toString cfg.monitorIntervalSeconds}
          done
        }

        # Run the monitor
        monitor_network
      '')
    ];

    # Create a systemd service to run the monitoring script
    systemd.services.network-monitoring = {
      description = "Network Stability Monitoring Service";
      documentation = ["https://github.com/olafkfreund/nixos-config/blob/main/doc/network-stability-guide.md"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      # Add proper ordering with stability helper when both are enabled
      serviceConfig = mkMerge [
          {
            Type = "simple";
            ExecStart = "${pkgs.writeShellScriptBin "network-monitor" ""}/bin/network-monitor";
            Restart = "on-failure";
            RestartSec = "30s";
            # Security hardening
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            # Create log directory with appropriate permissions
            StateDirectory = "network-monitoring";

            # Resource management
            CPUSchedulingPolicy = "idle";
            IOSchedulingClass = "idle";
            MemoryHigh = "75M";
            MemoryMax = "100M";

            # Provide better service isolation
            PrivateDevices = true;
            ProtectKernelTunables = true;
            RestrictAddressFamilies = "AF_INET AF_INET6";
            RestrictNamespaces = true;
          }
        ];
    };

    # Create a directory for network monitoring logs
    systemd.tmpfiles.rules = [
      "d ${cfg.logDir} 0755 root root -"

      # Create event marker file
      "f ${cfg.logDir}/events.json 0644 root root -"
    ];
  };
}
