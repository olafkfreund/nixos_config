{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.monitoring;
in {
  imports = [
    ./prometheus.nix
    ./grafana.nix
    ./node-exporter.nix
    ./alerting.nix
    ./loki.nix
    ./promtail.nix
    ./gpu-exporter.nix
    ./amd-gpu-exporter.nix
    ./nzbget-exporter.nix
    ./nzbget-dashboard.nix
    ./plex-exporter.nix
    ./plex-dashboard.nix
    ./network-discovery.nix
    ./traffic-analyzer.nix
    ./network-dashboards.nix
  ];

  options.monitoring = {
    enable = mkEnableOption "Enable monitoring and observability stack";

    mode = mkOption {
      type = types.enum ["server" "client" "standalone"];
      default = "client";
      description = ''
        Monitoring mode:
        - server: Runs Prometheus server, Grafana, and node exporter
        - client: Runs only node exporter (monitored by remote server)
        - standalone: Runs everything locally for single-host monitoring
      '';
    };

    serverHost = mkOption {
      type = types.str;
      default = "p620";
      description = "Hostname of the monitoring server";
    };

    retention = mkOption {
      type = types.str;
      default = "30d";
      description = "Data retention period for metrics";
    };

    logRetention = mkOption {
      type = types.str;
      default = "7d";
      description = "Data retention period for logs";
    };

    scrapeInterval = mkOption {
      type = types.str;
      default = "15s";
      description = "Default scrape interval for metrics collection";
    };

    hosts = mkOption {
      type = types.listOf types.str;
      default = ["p620" "razer" "p510" "dex5550"];
      description = "List of hosts to monitor";
    };

    # Network configuration
    network = {
      prometheusPort = mkOption {
        type = types.int;
        default = 9090;
        description = "Prometheus server port";
      };

      grafanaPort = mkOption {
        type = types.int;
        default = 3001;
        description = "Grafana server port";
      };

      nodeExporterPort = mkOption {
        type = types.int;
        default = 9100;
        description = "Node exporter port";
      };

      alertmanagerPort = mkOption {
        type = types.int;
        default = 9093;
        description = "Alertmanager port";
      };

      lokiPort = mkOption {
        type = types.int;
        default = 3100;
        description = "Loki server port";
      };

      lokiGrpcPort = mkOption {
        type = types.int;
        default = 9095;
        description = "Loki gRPC port";
      };

      promtailPort = mkOption {
        type = types.int;
        default = 9080;
        description = "Promtail server port";
      };

      promtailGrpcPort = mkOption {
        type = types.int;
        default = 9096;
        description = "Promtail gRPC port";
      };

      gpuExporterPort = mkOption {
        type = types.int;
        default = 9400;
        description = "NVIDIA GPU exporter port";
      };

      amdGpuExporterPort = mkOption {
        type = types.int;
        default = 9401;
        description = "AMD GPU exporter port";
      };
    };

    # Feature toggles
    features = {
      nodeExporter = mkOption {
        type = types.bool;
        default = true;
        description = "Enable node exporter for system metrics";
      };

      nixosMetrics = mkOption {
        type = types.bool;
        default = true;
        description = "Enable NixOS-specific metrics collection";
      };

      serviceMetrics = mkOption {
        type = types.bool;
        default = true;
        description = "Enable systemd service metrics";
      };

      aiMetrics = mkOption {
        type = types.bool;
        default = true;
        description = "Enable AI provider usage metrics";
      };

      networkMetrics = mkOption {
        type = types.bool;
        default = true;
        description = "Enable network and connectivity metrics";
      };

      alerting = mkOption {
        type = types.bool;
        default = true;
        description = "Enable alerting and notifications";
      };

      logging = mkOption {
        type = types.bool;
        default = true;
        description = "Enable centralized logging with Loki";
      };

      prometheus = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Prometheus metrics server";
      };

      grafana = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Grafana dashboard server";
      };

      gpuMetrics = mkOption {
        type = types.bool;
        default = false;
        description = "Enable NVIDIA GPU metrics collection";
      };

      amdGpuMetrics = mkOption {
        type = types.bool;
        default = false;
        description = "Enable AMD GPU metrics collection";
      };

      hardwareMonitor = mkOption {
        type = types.bool;
        default = false;
        description = "Enable hardware monitoring with desktop notifications";
      };

      networkDiscovery = mkOption {
        type = types.bool;
        default = false;
        description = "Enable network device discovery and classification";
      };

      trafficAnalysis = mkOption {
        type = types.bool;
        default = false;
        description = "Enable network traffic analysis and protocol detection";
      };

      networkDashboards = mkOption {
        type = types.bool;
        default = false;
        description = "Enable beautiful network activity dashboards";
      };
    };

    hardwareMonitor = {
      enable = mkEnableOption "Hardware monitoring with desktop notifications";
      
      interval = mkOption {
        type = types.int;
        default = 300; # 5 minutes
        description = "Check interval in seconds";
      };
      
      enableDesktopNotifications = mkOption {
        type = types.bool;
        default = true;
        description = "Enable desktop notifications for hardware issues";
      };
      
      logFile = mkOption {
        type = types.str;
        default = "/var/log/hardware-monitor.log";
        description = "Path to hardware monitor log file";
      };
      
      criticalThresholds = mkOption {
        type = types.attrsOf types.int;
        default = {
          diskUsage = 90;
          memoryUsage = 95;
          cpuLoad = 200;
          temperature = 90;
        };
        description = "Critical threshold values for system metrics";
      };
      
      warningThresholds = mkOption {
        type = types.attrsOf types.int;
        default = {
          diskUsage = 80;
          memoryUsage = 85;
          cpuLoad = 150;
          temperature = 80;
        };
        description = "Warning threshold values for system metrics";
      };
    };
  };

  config = mkIf cfg.enable {
    # Create monitoring user and group
    users.groups.monitoring = {};
    users.users.monitoring = {
      isSystemUser = true;
      group = "monitoring";
      description = "Monitoring service user";
    };

    # Open firewall ports for monitoring services
    networking.firewall = mkMerge [
      (mkIf (cfg.mode == "server" || cfg.mode == "standalone") {
        allowedTCPPorts = [
          cfg.network.prometheusPort
          cfg.network.grafanaPort
          cfg.network.alertmanagerPort
        ] ++ optionals cfg.features.logging [
          cfg.network.lokiPort
          cfg.network.lokiGrpcPort
        ];
      })
      
      (mkIf cfg.features.nodeExporter {
        allowedTCPPorts = [ cfg.network.nodeExporterPort ];
      })
      
      (mkIf cfg.features.logging {
        allowedTCPPorts = [
          cfg.network.promtailPort
          cfg.network.promtailGrpcPort
        ];
      })
      
      (mkIf cfg.features.gpuMetrics {
        allowedTCPPorts = [ cfg.network.gpuExporterPort ];
      })
      
      (mkIf cfg.features.amdGpuMetrics {
        allowedTCPPorts = [ cfg.network.amdGpuExporterPort ];
      })
    ];

    # Create monitoring data directories
    systemd.tmpfiles.rules = [
      "d /var/lib/monitoring 0755 monitoring monitoring -"
      "d /var/log/monitoring 0755 monitoring monitoring -"
    ] ++ optionals cfg.hardwareMonitor.enable [
      "d ${dirOf cfg.hardwareMonitor.logFile} 0755 root root -"
      "f ${cfg.hardwareMonitor.logFile} 0644 root root -"
    ];

    # Environment variables for monitoring services
    environment.sessionVariables = {
      MONITORING_MODE = cfg.mode;
      MONITORING_SERVER = cfg.serverHost;
      PROMETHEUS_URL = "http://${cfg.serverHost}:${toString cfg.network.prometheusPort}";
      GRAFANA_URL = "http://${cfg.serverHost}:${toString cfg.network.grafanaPort}";
      LOKI_URL = "http://${cfg.serverHost}:${toString cfg.network.lokiPort}";
    };

    # Install monitoring CLI tools
    environment.systemPackages = with pkgs; [
      prometheus
      grafana
      # Monitoring utilities
      htop
      iotop
      nethogs
      bandwhich
      procs
    ] ++ optionals cfg.hardwareMonitor.enable [
      libnotify    # notify-send
      lm_sensors   # sensors command  
      bc           # calculator for temperature comparisons
    ];

    # Hardware monitoring service
    systemd.services.hardware-monitor = mkIf cfg.hardwareMonitor.enable {
      description = "Hardware Monitor Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "systemd-journald.service" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = pkgs.writeShellScript "hardware-monitor" ''
          #!/bin/bash
          set -euo pipefail
          
          # Configuration
          SCRIPT_NAME="Hardware Monitor"
          LOG_FILE="${cfg.hardwareMonitor.logFile}"
          STATE_FILE="/tmp/hardware-monitor-state" 
          CHECK_INTERVAL_MINUTES=5
          
          # Hardware-specific patterns based on host
          HOSTNAME=$(${pkgs.inetutils}/bin/hostname)
          
          # Common hardware issue patterns
          declare -A PATTERNS=(
              ["usb_disconnect"]="usb.*disconnect"
              ["usb_power_fail"]="Cannot enable.*USB cable"
              ["disk_error"]="ata.*error|sd.*error|nvme.*error"
              ["memory_error"]="Machine Check Exception|memory.*error|EDAC.*error"
              ["oom_kill"]="Out of memory.*Killed process"
              ["network_down"]="Link is Down|carrier lost|network.*timeout"
              ["thermal_throttle"]="thermal.*throttle|temperature.*critical"
              ["power_fail"]="power.*supply.*fail|voltage.*out of range"
          )
          
          # Host-specific patterns
          case "$HOSTNAME" in
              "p620")
                  PATTERNS+=(
                      ["amd_gpu_error"]="amdgpu.*error|radeon.*error|DRM.*error"
                      ["rocm_fail"]="ROCm.*error|HSA.*fail"
                  )
                  ;;
              "razer")
                  PATTERNS+=(
                      ["nvidia_error"]="nvidia.*error|NVRM.*error"
                      ["intel_gpu_error"]="i915.*error|intel.*graphics.*error"
                      ["optimus_fail"]="optimus.*error|gpu.*switch.*fail"
                  )
                  ;;
          esac
          
          # Notification function
          send_notification() {
              local severity="$1"
              local title="$2"
              local message="$3"
              local icon="$4"
              
              echo "$(date '+%Y-%m-%d %H:%M:%S') [$severity] $title: $message" >> "$LOG_FILE"
              
              if command -v notify-send >/dev/null 2>&1; then
                  case "$severity" in
                      "CRITICAL") urgency="critical"; timeout=0 ;;
                      "WARNING") urgency="normal"; timeout=10000 ;;
                      "INFO") urgency="low"; timeout=5000 ;;
                  esac
                  
                  DISPLAY=:0 notify-send --urgency="$urgency" --expire-time="$timeout" --icon="$icon" --category="hardware" "$title" "$message" || true
              fi
              
              case "$severity" in
                  "CRITICAL") logger -p daemon.crit -t "$SCRIPT_NAME" "$title: $message" ;;
                  "WARNING") logger -p daemon.warning -t "$SCRIPT_NAME" "$title: $message" ;;
                  "INFO") logger -p daemon.info -t "$SCRIPT_NAME" "$title: $message" ;;
              esac
          }
          
          # Check for hardware issues in logs
          check_hardware_issues() {
              local since_time="$1"
              local issues_found=0
              
              local journal_output
              journal_output=$(journalctl --since="$since_time" --no-pager -q 2>/dev/null || true)
              
              if [[ -z "$journal_output" ]]; then
                  return 0
              fi
              
              for pattern_name in "$${!PATTERNS[@]}"; do
                  local pattern="$${PATTERNS[$pattern_name]}"
                  local matches
                  
                  matches=$(echo "$journal_output" | grep -iE "$pattern" || true)
                  
                  if [[ -n "$matches" ]]; then
                      issues_found=$((issues_found + 1))
                      local count=$(echo "$matches" | wc -l)
                      
                      case "$pattern_name" in
                          *"error"|*"fail"|*"critical"|"memory_error"|"oom_kill"|"thermal_throttle")
                              send_notification "CRITICAL" "Hardware Issue: $${pattern_name//_/ }" "$count occurrence(s) detected!" "dialog-error"
                              ;;
                          *"disconnect"|*"down"|*"timeout"|*"throttle")
                              send_notification "WARNING" "Hardware Warning: $${pattern_name//_/ }" "$count occurrence(s) detected." "dialog-warning"
                              ;;
                          *)
                              send_notification "INFO" "Hardware Notice: $${pattern_name//_/ }" "$count occurrence(s) detected." "dialog-information"
                              ;;
                      esac
                  fi
              done
              
              return $issues_found
          }
          
          # Main monitoring function
          main() {
              local since_time="5 minutes ago"
              if [[ -f "$STATE_FILE" ]]; then
                  since_time=$(cat "$STATE_FILE" 2>/dev/null || echo "5 minutes ago")
              fi
              
              date '+%Y-%m-%d %H:%M:%S' > "$STATE_FILE"
              
              local total_issues=0
              echo "$(date '+%Y-%m-%d %H:%M:%S') Starting hardware monitoring check..." >> "$LOG_FILE"
              
              if check_hardware_issues "$since_time"; then
                  total_issues=$((total_issues + $?))
              fi
              
              if [[ "$total_issues" -gt 0 ]]; then
                  send_notification "WARNING" "Hardware Monitor Summary" "$total_issues hardware issue(s) detected." "dialog-warning"
              fi
          }
          
          # Daemon mode
          while true; do
              main
              sleep $((CHECK_INTERVAL_MINUTES * 60))
          done
        '';
        Restart = "always";
        RestartSec = "30s";
        
        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        ReadWritePaths = [ 
          cfg.hardwareMonitor.logFile 
          "/tmp"
        ];
        
        User = "root";
        Group = "root";
        
        Environment = [
          "DISPLAY=:0"
        ];
      };
    };

    # Timer for regular checks (backup)
    systemd.timers.hardware-monitor = mkIf cfg.hardwareMonitor.enable {
      description = "Hardware Monitor Timer";
      wantedBy = [ "timers.target" ];
      
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "${toString cfg.hardwareMonitor.interval}s";
        Persistent = true;
        AccuracySec = "30s";
      };
    };

    # Logrotate configuration
    services.logrotate.settings."${cfg.hardwareMonitor.logFile}" = mkIf cfg.hardwareMonitor.enable {
      frequency = "weekly";
      rotate = 4;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      postrotate = "systemctl reload hardware-monitor || true";
    };
  };
}