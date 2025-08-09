# Performance Monitoring and Analytics Module
{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.monitoring.performanceAnalytics;
in
{
  options.monitoring.performanceAnalytics = {
    enable = mkEnableOption "Enable performance monitoring and analytics";

    dataRetention = mkOption {
      type = types.str;
      default = "30d";
      description = "Performance data retention period";
    };

    analysisInterval = mkOption {
      type = types.str;
      default = "5m";
      description = "Performance analysis interval";
    };

    metricsCollection = {
      enable = mkEnableOption "Enable comprehensive metrics collection";

      systemMetrics = mkOption {
        type = types.bool;
        default = true;
        description = "Collect system performance metrics";
      };

      applicationMetrics = mkOption {
        type = types.bool;
        default = true;
        description = "Collect application performance metrics";
      };

      networkMetrics = mkOption {
        type = types.bool;
        default = true;
        description = "Collect network performance metrics";
      };

      storageMetrics = mkOption {
        type = types.bool;
        default = true;
        description = "Collect storage performance metrics";
      };

      aiMetrics = mkOption {
        type = types.bool;
        default = true;
        description = "Collect AI workload performance metrics";
      };
    };

    analytics = {
      enable = mkEnableOption "Enable performance analytics and insights";

      trendAnalysis = mkOption {
        type = types.bool;
        default = true;
        description = "Enable performance trend analysis";
      };

      anomalyDetection = mkOption {
        type = types.bool;
        default = true;
        description = "Enable performance anomaly detection";
      };

      predictiveAnalysis = mkOption {
        type = types.bool;
        default = true;
        description = "Enable predictive performance analysis";
      };

      bottleneckDetection = mkOption {
        type = types.bool;
        default = true;
        description = "Enable performance bottleneck detection";
      };
    };

    reporting = {
      enable = mkEnableOption "Enable performance reporting";

      dailyReports = mkOption {
        type = types.bool;
        default = true;
        description = "Generate daily performance reports";
      };

      weeklyReports = mkOption {
        type = types.bool;
        default = true;
        description = "Generate weekly performance reports";
      };

      alertThresholds = mkOption {
        type = types.bool;
        default = true;
        description = "Enable performance threshold alerting";
      };
    };

    dashboards = {
      enable = mkEnableOption "Enable performance dashboards";

      realTimeMetrics = mkOption {
        type = types.bool;
        default = true;
        description = "Enable real-time performance dashboards";
      };

      historicalAnalysis = mkOption {
        type = types.bool;
        default = true;
        description = "Enable historical performance analysis";
      };

      customMetrics = mkOption {
        type = types.bool;
        default = true;
        description = "Enable custom performance metrics dashboards";
      };
    };
  };

  config = mkIf cfg.enable {
    # Performance Analytics Service
    systemd.services.performance-analytics = {
      description = "Performance Analytics Service";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        Restart = "always";
        RestartSec = "10s";
        Environment = [
          "PATH=${lib.makeBinPath (with pkgs; [procps gawk iproute2 util-linux bc coreutils gnugrep gnused])}"
        ];
        ExecStart = pkgs.writeShellScript "performance-analytics" ''
          #!/bin/bash

          LOG_FILE="/var/log/performance-analytics/analytics.log"
          METRICS_DIR="/var/lib/performance-analytics"
          mkdir -p "$(dirname "$LOG_FILE")" "$METRICS_DIR"
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1

          echo "[$(date)] Starting Performance Analytics Service..."
          echo "[$(date)] Data retention: ${cfg.dataRetention}"
          echo "[$(date)] Analysis interval: ${cfg.analysisInterval}"

          # Initialize analytics database
          ANALYTICS_DB="$METRICS_DIR/performance_analytics.json"
          if [ ! -f "$ANALYTICS_DB" ]; then
            cat > "$ANALYTICS_DB" << 'EOF'
          {
            "initialized": "$(date -Iseconds)",
            "metrics_history": [],
            "analytics": {
              "trends": {},
              "anomalies": [],
              "predictions": {},
              "bottlenecks": []
            },
            "baselines": {}
          }
          EOF
            echo "[$(date)] Initialized analytics database"
          fi

          # Function to collect system metrics
          collect_system_metrics() {
            local timestamp=$(date -Iseconds)

            ${optionalString cfg.metricsCollection.systemMetrics ''
            # CPU metrics
            local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
            local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')

            # Memory metrics
            local memory_total=$(free -b | grep Mem | awk '{print $2}')
            local memory_used=$(free -b | grep Mem | awk '{print $3}')
            local memory_percent=$(echo "scale=2; $memory_used * 100 / $memory_total" | bc)

            # System uptime
            local uptime_seconds=$(awk '{print $1}' /proc/uptime)

            echo "$timestamp,system,cpu_usage,$cpu_usage"
            echo "$timestamp,system,load_average,$load_avg"
            echo "$timestamp,system,memory_percent,$memory_percent"
            echo "$timestamp,system,uptime_seconds,$uptime_seconds"
          ''}

            ${optionalString cfg.metricsCollection.networkMetrics ''
            # Network metrics
            local network_rx=$(cat /proc/net/dev | tail -n +3 | awk -F: '{sum += $2} END {print sum}')
            local network_tx=$(cat /proc/net/dev | tail -n +3 | awk '{sum += $10} END {print sum}')
            local connections=$(ss -tuln | grep LISTEN | wc -l)

            echo "$timestamp,network,rx_bytes,$network_rx"
            echo "$timestamp,network,tx_bytes,$network_tx"
            echo "$timestamp,network,connections,$connections"
          ''}

            ${optionalString cfg.metricsCollection.storageMetrics ''
            # Storage metrics
            local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
            local inode_usage=$(df -i / | tail -1 | awk '{print $5}' | sed 's/%//')

            echo "$timestamp,storage,disk_usage_percent,$disk_usage"
            echo "$timestamp,storage,inode_usage_percent,$inode_usage"
          ''}

            ${optionalString cfg.metricsCollection.applicationMetrics ''
            # Application metrics
            local ai_services=$(${pkgs.systemd}/bin/systemctl list-units --type=service --state=running | grep -c ai- || echo 0)
            local monitoring_services=$(${pkgs.systemd}/bin/systemctl list-units --type=service --state=running | grep -E "(prometheus|grafana|node-exporter)" | wc -l)

            echo "$timestamp,application,ai_services_running,$ai_services"
            echo "$timestamp,application,monitoring_services_running,$monitoring_services"
          ''}

            ${optionalString cfg.metricsCollection.aiMetrics ''
            # AI performance metrics
            if [ -f "/var/lib/ai-analysis/performance-metrics.json" ]; then
              local ai_response_time=$(jq -r '.ai_metrics.last_response_time // "0"' /var/lib/ai-analysis/performance-metrics.json 2>/dev/null || echo "0")
              local ai_provider_status=$(jq -r '.ai_metrics.ai_provider_status // "0"' /var/lib/ai-analysis/performance-metrics.json 2>/dev/null || echo "0")

              echo "$timestamp,ai,response_time_ms,$ai_response_time"
              echo "$timestamp,ai,provider_status,$ai_provider_status"
            fi
          ''}
          }

          # Function to analyze performance trends
          analyze_trends() {
            ${optionalString cfg.analytics.trendAnalysis ''
            echo "[$(date)] Analyzing performance trends..."

            # Calculate moving averages and trends
            local metrics_file="$METRICS_DIR/current_metrics.csv"

            if [ -f "$metrics_file" ] && [ $(wc -l < "$metrics_file") -gt 10 ]; then
              # CPU usage trend
              local cpu_trend=$(tail -n 20 "$metrics_file" | grep "system,cpu_usage" | awk -F, '{sum+=$4; count++} END {if(count>0) print sum/count; else print 0}')

              # Memory usage trend
              local memory_trend=$(tail -n 20 "$metrics_file" | grep "system,memory_percent" | awk -F, '{sum+=$4; count++} END {if(count>0) print sum/count; else print 0}')

              # Store trends in analytics database
              local trend_data="{\"timestamp\": \"$(date -Iseconds)\", \"cpu_avg\": $cpu_trend, \"memory_avg\": $memory_trend}"
              echo "[$(date)] Current trends - CPU: $cpu_trend%, Memory: $memory_trend%"
            fi
          ''}
          }

          # Function to detect anomalies
          detect_anomalies() {
            ${optionalString cfg.analytics.anomalyDetection ''
            echo "[$(date)] Detecting performance anomalies..."

            local metrics_file="$METRICS_DIR/current_metrics.csv"
            local anomalies_file="$METRICS_DIR/anomalies.log"

            if [ -f "$metrics_file" ]; then
              # Check for CPU anomalies (usage > 90%)
              local high_cpu=$(tail -n 5 "$metrics_file" | grep "system,cpu_usage" | awk -F, '$4 > 90 {print $1, $4}')
              if [ -n "$high_cpu" ]; then
                echo "[$(date)] ANOMALY: High CPU usage detected: $high_cpu" | tee -a "$anomalies_file"
              fi

              # Check for memory anomalies (usage > 95%)
              local high_memory=$(tail -n 5 "$metrics_file" | grep "system,memory_percent" | awk -F, '$4 > 95 {print $1, $4}')
              if [ -n "$high_memory" ]; then
                echo "[$(date)] ANOMALY: High memory usage detected: $high_memory" | tee -a "$anomalies_file"
              fi

              # Check for disk anomalies (usage > 90%)
              local high_disk=$(tail -n 5 "$metrics_file" | grep "storage,disk_usage_percent" | awk -F, '$4 > 90 {print $1, $4}')
              if [ -n "$high_disk" ]; then
                echo "[$(date)] ANOMALY: High disk usage detected: $high_disk" | tee -a "$anomalies_file"
              fi
            fi
          ''}
          }

          # Function to detect bottlenecks
          detect_bottlenecks() {
            ${optionalString cfg.analytics.bottleneckDetection ''
            echo "[$(date)] Detecting performance bottlenecks..."

            # Check for I/O bottlenecks
            local io_wait=$(top -bn1 | grep "Cpu(s)" | awk '{print $10}' | sed 's/%wa,//' | sed 's/%wa//')
            if [ -n "$io_wait" ] && (( $(echo "$io_wait > 30" | bc -l) )); then
              echo "[$(date)] BOTTLENECK: High I/O wait detected: $io_wait%"
            fi

            # Check for network bottlenecks
            if [ -f "/var/lib/network-tuning/metrics.json" ]; then
              local connection_count=$(jq -r '.tcp_connections // 0' /var/lib/network-tuning/metrics.json 2>/dev/null || echo 0)
              if [ "$connection_count" -gt 1000 ]; then
                echo "[$(date)] BOTTLENECK: High connection count detected: $connection_count"
              fi
            fi

            # Check for memory bottlenecks
            local swap_usage=$(free | grep Swap | awk '{if($2>0) printf "%.1f", $3/$2*100; else print "0"}')
            if (( $(echo "$swap_usage > 50" | bc -l) )); then
              echo "[$(date)] BOTTLENECK: High swap usage detected: $swap_usage%"
            fi
          ''}
          }

          # Function to generate predictions
          generate_predictions() {
            ${optionalString cfg.analytics.predictiveAnalysis ''
            echo "[$(date)] Generating performance predictions..."

            local metrics_file="$METRICS_DIR/current_metrics.csv"
            local predictions_file="$METRICS_DIR/predictions.json"

            if [ -f "$metrics_file" ] && [ $(wc -l < "$metrics_file") -gt 50 ]; then
              # Simple linear trend prediction for next hour
              local cpu_prediction=$(tail -n 30 "$metrics_file" | grep "system,cpu_usage" | awk -F, '
                {x++; y+=$4; xy+=x*$4; x2+=x*x}
                END {
                  if(x>1) {
                    slope = (x*xy - x*y) / (x*x2 - x*x)
                    intercept = (y - slope*x) / x
                    next_value = slope*(x+12) + intercept  # 12 more 5-minute intervals = 1 hour
                    printf "%.1f", (next_value > 0 && next_value < 100) ? next_value : y/x
                  } else print "0"
                }
              ')

              echo "[$(date)] Predicted CPU usage in 1 hour: $cpu_prediction%"
              echo "{\"timestamp\": \"$(date -Iseconds)\", \"cpu_1h\": $cpu_prediction}" > "$predictions_file"
            fi
          ''}
          }

          # Main monitoring loop
          while true; do
            echo "[$(date)] Collecting performance metrics..."

            # Collect metrics
            METRICS_FILE="$METRICS_DIR/current_metrics.csv"
            collect_system_metrics >> "$METRICS_FILE"

            # Rotate metrics file if it gets too large (keep last 10000 lines)
            if [ $(wc -l < "$METRICS_FILE") -gt 10000 ]; then
              tail -n 5000 "$METRICS_FILE" > "$METRICS_FILE.tmp"
              mv "$METRICS_FILE.tmp" "$METRICS_FILE"
            fi

            # Perform analytics
            analyze_trends
            detect_anomalies
            detect_bottlenecks
            generate_predictions

            # Clean up old data based on retention policy
            find "$METRICS_DIR" -name "*.csv" -mtime +30 -delete 2>/dev/null || true
            find "$METRICS_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true

            # Parse interval (convert 5m to seconds)
            SLEEP_SECONDS=$(echo "${cfg.analysisInterval}" | sed 's/m/*60/' | sed 's/s//' | bc)
            sleep "$SLEEP_SECONDS"
          done
        '';
      };
    };

    # Performance Report Generator
    systemd.services.performance-reporter = mkIf cfg.reporting.enable {
      description = "Performance Report Generator";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Environment = [
          "PATH=${lib.makeBinPath (with pkgs; [procps gawk iproute2 util-linux bc coreutils gnugrep gnused])}"
        ];
        ExecStart = pkgs.writeShellScript "performance-reporter" ''
          #!/bin/bash

          REPORTS_DIR="/var/lib/performance-analytics/reports"
          METRICS_DIR="/var/lib/performance-analytics"
          mkdir -p "$REPORTS_DIR"

          echo "[$(date)] Generating performance reports..."

          ${optionalString cfg.reporting.dailyReports ''
              # Daily performance report
              DAILY_REPORT="$REPORTS_DIR/daily-$(date +%Y-%m-%d).json"

              if [ -f "$METRICS_DIR/current_metrics.csv" ]; then
                # Calculate daily averages
                TODAY=$(date +%Y-%m-%d)
                DAILY_METRICS=$(grep "$TODAY" "$METRICS_DIR/current_metrics.csv" 2>/dev/null || echo "")

                if [ -n "$DAILY_METRICS" ]; then
                  CPU_AVG=$(echo "$DAILY_METRICS" | grep "system,cpu_usage" | awk -F, '{sum+=$4; count++} END {if(count>0) printf "%.1f", sum/count; else print "0"}')
                  MEMORY_AVG=$(echo "$DAILY_METRICS" | grep "system,memory_percent" | awk -F, '{sum+=$4; count++} END {if(count>0) printf "%.1f", sum/count; else print "0"}')
                  DISK_AVG=$(echo "$DAILY_METRICS" | grep "storage,disk_usage_percent" | awk -F, '{sum+=$4; count++} END {if(count>0) printf "%.1f", sum/count; else print "0"}')

                  cat > "$DAILY_REPORT" << EOF
            {
              "date": "$TODAY",
              "summary": {
                "cpu_average": $CPU_AVG,
                "memory_average": $MEMORY_AVG,
                "disk_average": $DISK_AVG
              },
              "anomalies": $([ -f "$METRICS_DIR/anomalies.log" ] && grep "$TODAY" "$METRICS_DIR/anomalies.log" | wc -l || echo 0),
              "generated": "$(date -Iseconds)"
            }
            EOF

                  echo "[$(date)] Daily report generated: $DAILY_REPORT"
                fi
              fi
          ''}

          ${optionalString cfg.reporting.weeklyReports ''
              # Weekly performance report (run on Sundays)
              if [ $(date +%u) -eq 7 ]; then
                WEEKLY_REPORT="$REPORTS_DIR/weekly-$(date +%Y-W%V).json"
                WEEK_START=$(date -d "last Monday" +%Y-%m-%d)

                echo "[$(date)] Generating weekly report starting from $WEEK_START"

                if [ -f "$METRICS_DIR/current_metrics.csv" ]; then
                  WEEK_METRICS=$(grep -E "($WEEK_START|$(date -d "$WEEK_START +1 day" +%Y-%m-%d)|$(date -d "$WEEK_START +2 days" +%Y-%m-%d)|$(date -d "$WEEK_START +3 days" +%Y-%m-%d)|$(date -d "$WEEK_START +4 days" +%Y-%m-%d)|$(date -d "$WEEK_START +5 days" +%Y-%m-%d)|$(date -d "$WEEK_START +6 days" +%Y-%m-%d))" "$METRICS_DIR/current_metrics.csv" 2>/dev/null || echo "")

                  if [ -n "$WEEK_METRICS" ]; then
                    CPU_WEEK_AVG=$(echo "$WEEK_METRICS" | grep "system,cpu_usage" | awk -F, '{sum+=$4; count++} END {if(count>0) printf "%.1f", sum/count; else print "0"}')
                    MEMORY_WEEK_AVG=$(echo "$WEEK_METRICS" | grep "system,memory_percent" | awk -F, '{sum+=$4; count++} END {if(count>0) printf "%.1f", sum/count; else print "0"}')

                    cat > "$WEEKLY_REPORT" << EOF
            {
              "week": "$(date +%Y-W%V)",
              "week_start": "$WEEK_START",
              "summary": {
                "cpu_weekly_average": $CPU_WEEK_AVG,
                "memory_weekly_average": $MEMORY_WEEK_AVG
              },
              "generated": "$(date -Iseconds)"
            }
            EOF

                    echo "[$(date)] Weekly report generated: $WEEKLY_REPORT"
                  fi
                fi
              fi
          ''}

          echo "[$(date)] Performance reporting completed"
        '';
      };
    };

    # Performance Dashboard Provisioning
    systemd.services.performance-dashboard-provisioner = mkIf cfg.dashboards.enable {
      description = "Performance Dashboard Provisioner";
      after = [ "grafana.service" ];
      wants = [ "grafana.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Environment = [
          "PATH=${lib.makeBinPath (with pkgs; [procps gawk iproute2 util-linux bc coreutils gnugrep gnused])}"
        ];
        ExecStart = pkgs.writeShellScript "performance-dashboard-provisioner" ''
          #!/bin/bash

          DASHBOARD_DIR="/var/lib/grafana/dashboards"
          mkdir -p "$DASHBOARD_DIR"

          echo "[$(date)] Provisioning performance dashboards..."

          ${optionalString cfg.dashboards.realTimeMetrics ''
              # Real-time Performance Dashboard
              cat > "$DASHBOARD_DIR/performance-realtime.json" << 'EOF'
            {
              "dashboard": {
                "id": null,
                "title": "Real-time Performance Analytics",
                "tags": ["performance", "realtime"],
                "timezone": "browser",
                "panels": [
                  {
                    "id": 1,
                    "title": "CPU Usage Over Time",
                    "type": "timeseries",
                    "targets": [
                      {
                        "expr": "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
                        "legendFormat": "CPU Usage %"
                      }
                    ],
                    "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
                  },
                  {
                    "id": 2,
                    "title": "Memory Usage",
                    "type": "timeseries",
                    "targets": [
                      {
                        "expr": "(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100",
                        "legendFormat": "Memory Usage %"
                      }
                    ],
                    "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
                  },
                  {
                    "id": 3,
                    "title": "Disk I/O",
                    "type": "timeseries",
                    "targets": [
                      {
                        "expr": "irate(node_disk_read_bytes_total[5m])",
                        "legendFormat": "Read Bytes/sec"
                      },
                      {
                        "expr": "irate(node_disk_written_bytes_total[5m])",
                        "legendFormat": "Write Bytes/sec"
                      }
                    ],
                    "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
                  },
                  {
                    "id": 4,
                    "title": "Network Traffic",
                    "type": "timeseries",
                    "targets": [
                      {
                        "expr": "irate(node_network_receive_bytes_total{device!=\"lo\"}[5m])",
                        "legendFormat": "RX Bytes/sec"
                      },
                      {
                        "expr": "irate(node_network_transmit_bytes_total{device!=\"lo\"}[5m])",
                        "legendFormat": "TX Bytes/sec"
                      }
                    ],
                    "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
                  }
                ],
                "time": {"from": "now-1h", "to": "now"},
                "refresh": "10s"
              },
              "overwrite": true
            }
            EOF
          ''}

          ${optionalString cfg.dashboards.historicalAnalysis ''
              # Historical Performance Analysis Dashboard
              cat > "$DASHBOARD_DIR/performance-historical.json" << 'EOF'
            {
              "dashboard": {
                "id": null,
                "title": "Historical Performance Analysis",
                "tags": ["performance", "historical"],
                "timezone": "browser",
                "panels": [
                  {
                    "id": 1,
                    "title": "Performance Trends (7 days)",
                    "type": "timeseries",
                    "targets": [
                      {
                        "expr": "avg_over_time(node_load1[1h])",
                        "legendFormat": "Load Average"
                      }
                    ],
                    "gridPos": {"h": 8, "w": 24, "x": 0, "y": 0}
                  },
                  {
                    "id": 2,
                    "title": "Resource Utilization Heatmap",
                    "type": "heatmap",
                    "targets": [
                      {
                        "expr": "rate(node_cpu_seconds_total{mode!=\"idle\"}[5m])",
                        "legendFormat": "CPU Utilization"
                      }
                    ],
                    "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8}
                  }
                ],
                "time": {"from": "now-7d", "to": "now"},
                "refresh": "1m"
              },
              "overwrite": true
            }
            EOF
          ''}

          echo "[$(date)] Performance dashboards provisioned"
        '';
      };
    };

    # Timers for regular operations
    systemd.timers.performance-reporter = mkIf cfg.reporting.enable {
      description = "Performance Report Generator Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "10m";
      };
    };

    # Create directories
    systemd.tmpfiles.rules = [
      "d /var/lib/performance-analytics 0755 root root -"
      "d /var/log/performance-analytics 0755 root root -"
      "d /var/lib/performance-analytics/reports 0755 root root -"
    ];

    # Use shared monitoring dependencies (includes bc, jq, python3)
    features.packages.monitoringTools = true;

    # Additional specific packages for performance analytics
    environment.systemPackages = with pkgs; [
      gnuplot # Data visualization
      procps # Provides top, free commands
      gawk # Provides awk command
      iproute2 # Provides ss command for network monitoring
      util-linux # Provides additional system utilities
      gnugrep # Provides grep command
      gnused # Provides sed command
    ];
  };
}
