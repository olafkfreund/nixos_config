# Production Monitoring Dashboard Module
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.ai.productionDashboard;
in
{
  options.ai.productionDashboard = {
    enable = mkEnableOption "Enable AI production monitoring dashboard";

    grafanaUrl = mkOption {
      type = types.str;
      default = "http://dex5550:3001";
      description = "Grafana server URL for dashboard deployment";
    };

    prometheusUrl = mkOption {
      type = types.str;
      default = "http://dex5550:9090";
      description = "Prometheus server URL for metrics collection";
    };

    dashboardPath = mkOption {
      type = types.str;
      default = "/var/lib/grafana/dashboards";
      description = "Path to store Grafana dashboard configurations";
    };

    refreshInterval = mkOption {
      type = types.str;
      default = "30s";
      description = "Dashboard refresh interval";
    };

    enableAlerts = mkOption {
      type = types.bool;
      default = true;
      description = "Enable dashboard alerting panels";
    };

    criticalThresholds = mkOption {
      type = types.attrs;
      default = {
        cpuUsage = 80;
        memoryUsage = 85;
        diskUsage = 70;
        aiResponseTime = 10000; # 10 seconds
        sshFailedAttempts = 10;
        serviceDowntime = 300; # 5 minutes
      };
      description = "Critical threshold values for alerts";
    };
  };

  config = mkIf cfg.enable {
    # Production AI Analysis Dashboard
    systemd.services.ai-production-dashboard = {
      description = "AI Production Dashboard Provisioner";
      after = [ "network.target" ];
      wants = [ "network.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "provision-production-dashboard" ''
          #!/bin/bash
          
          LOG_FILE="/var/log/ai-analysis/production-dashboard.log"
          DASHBOARD_DIR="${cfg.dashboardPath}"
          
          mkdir -p "$(dirname "$LOG_FILE")"
          mkdir -p "$DASHBOARD_DIR"
          
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1
          
          echo "[$(date)] Starting production dashboard provisioning..."
          
          # Create AI Production Overview Dashboard
          cat > "$DASHBOARD_DIR/ai-production-overview.json" << 'EOF'
          {
            "dashboard": {
              "id": null,
              "title": "AI Production Overview",
              "description": "Comprehensive AI system production monitoring dashboard",
              "tags": ["ai", "production", "monitoring", "overview"],
              "timezone": "browser",
              "refresh": "${cfg.refreshInterval}",
              "time": {
                "from": "now-1h",
                "to": "now"
              },
              "panels": [
                {
                  "id": 1,
                  "title": "System Health Overview",
                  "type": "stat",
                  "gridPos": { "h": 4, "w": 24, "x": 0, "y": 0 },
                  "targets": [
                    {
                      "expr": "up{job=\"node-exporter\"}",
                      "legendFormat": "{{instance}} Status",
                      "refId": "A"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": { "mode": "thresholds" },
                      "thresholds": {
                        "steps": [
                          { "color": "red", "value": 0 },
                          { "color": "green", "value": 1 }
                        ]
                      },
                      "mappings": [
                        { "options": { "0": { "text": "DOWN" }, "1": { "text": "UP" } }, "type": "value" }
                      ]
                    }
                  }
                },
                {
                  "id": 2,
                  "title": "AI Analysis Services Status",
                  "type": "stat",
                  "gridPos": { "h": 4, "w": 12, "x": 0, "y": 4 },
                  "targets": [
                    {
                      "expr": "up{job=\"ai-analysis\"}",
                      "legendFormat": "AI Analysis",
                      "refId": "A"
                    },
                    {
                      "expr": "up{job=\"ollama\"}",
                      "legendFormat": "Ollama",
                      "refId": "B"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": { "mode": "thresholds" },
                      "thresholds": {
                        "steps": [
                          { "color": "red", "value": 0 },
                          { "color": "green", "value": 1 }
                        ]
                      }
                    }
                  }
                },
                {
                  "id": 3,
                  "title": "AI Provider Response Times",
                  "type": "timeseries",
                  "gridPos": { "h": 8, "w": 12, "x": 0, "y": 8 },
                  "targets": [
                    {
                      "expr": "ai_provider_response_time_ms",
                      "legendFormat": "{{provider}} Response Time",
                      "refId": "A"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": { "mode": "palette-classic" },
                      "unit": "ms",
                      "thresholds": {
                        "steps": [
                          { "color": "green", "value": 0 },
                          { "color": "yellow", "value": 5000 },
                          { "color": "red", "value": ${toString cfg.criticalThresholds.aiResponseTime} }
                        ]
                      }
                    }
                  }
                },
                {
                  "id": 4,
                  "title": "System Resource Usage",
                  "type": "timeseries",
                  "gridPos": { "h": 8, "w": 12, "x": 12, "y": 8 },
                  "targets": [
                    {
                      "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
                      "legendFormat": "{{instance}} CPU Usage",
                      "refId": "A"
                    },
                    {
                      "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
                      "legendFormat": "{{instance}} Memory Usage",
                      "refId": "B"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": { "mode": "palette-classic" },
                      "unit": "percent",
                      "min": 0,
                      "max": 100,
                      "thresholds": {
                        "steps": [
                          { "color": "green", "value": 0 },
                          { "color": "yellow", "value": 70 },
                          { "color": "red", "value": 90 }
                        ]
                      }
                    }
                  }
                },
                {
                  "id": 5,
                  "title": "Storage Usage by Host",
                  "type": "bargauge",
                  "gridPos": { "h": 6, "w": 12, "x": 0, "y": 16 },
                  "targets": [
                    {
                      "expr": "100 - ((node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"}) * 100)",
                      "legendFormat": "{{instance}} Root Disk",
                      "refId": "A"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": { "mode": "thresholds" },
                      "unit": "percent",
                      "min": 0,
                      "max": 100,
                      "thresholds": {
                        "steps": [
                          { "color": "green", "value": 0 },
                          { "color": "yellow", "value": 60 },
                          { "color": "red", "value": ${toString cfg.criticalThresholds.diskUsage} }
                        ]
                      }
                    }
                  }
                },
                {
                  "id": 6,
                  "title": "SSH Security Monitoring",
                  "type": "timeseries",
                  "gridPos": { "h": 6, "w": 12, "x": 12, "y": 16 },
                  "targets": [
                    {
                      "expr": "rate(ssh_failed_attempts_total[5m]) * 60",
                      "legendFormat": "{{instance}} Failed SSH Attempts/min",
                      "refId": "A"
                    },
                    {
                      "expr": "fail2ban_banned_ips_total",
                      "legendFormat": "{{instance}} Banned IPs",
                      "refId": "B"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": { "mode": "palette-classic" },
                      "unit": "short",
                      "thresholds": {
                        "steps": [
                          { "color": "green", "value": 0 },
                          { "color": "yellow", "value": 5 },
                          { "color": "red", "value": ${toString cfg.criticalThresholds.sshFailedAttempts} }
                        ]
                      }
                    }
                  }
                },
                {
                  "id": 7,
                  "title": "AI Analysis Success Rate",
                  "type": "stat",
                  "gridPos": { "h": 4, "w": 6, "x": 0, "y": 22 },
                  "targets": [
                    {
                      "expr": "(ai_analysis_success_total / ai_analysis_total) * 100",
                      "legendFormat": "Success Rate",
                      "refId": "A"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": { "mode": "thresholds" },
                      "unit": "percent",
                      "thresholds": {
                        "steps": [
                          { "color": "red", "value": 0 },
                          { "color": "yellow", "value": 80 },
                          { "color": "green", "value": 95 }
                        ]
                      }
                    }
                  }
                },
                {
                  "id": 8,
                  "title": "Performance Optimization Status",
                  "type": "stat",
                  "gridPos": { "h": 4, "w": 6, "x": 6, "y": 22 },
                  "targets": [
                    {
                      "expr": "ai_performance_optimization_last_run",
                      "legendFormat": "Last Optimization",
                      "refId": "A"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": { "mode": "thresholds" },
                      "unit": "dateTimeFromNow",
                      "thresholds": {
                        "steps": [
                          { "color": "green", "value": 0 },
                          { "color": "yellow", "value": 3600 },
                          { "color": "red", "value": 7200 }
                        ]
                      }
                    }
                  }
                },
                {
                  "id": 9,
                  "title": "Service Uptime",
                  "type": "stat",
                  "gridPos": { "h": 4, "w": 6, "x": 12, "y": 22 },
                  "targets": [
                    {
                      "expr": "time() - process_start_time_seconds",
                      "legendFormat": "{{instance}} Uptime",
                      "refId": "A"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": { "mode": "thresholds" },
                      "unit": "s",
                      "thresholds": {
                        "steps": [
                          { "color": "red", "value": 0 },
                          { "color": "yellow", "value": 3600 },
                          { "color": "green", "value": 86400 }
                        ]
                      }
                    }
                  }
                },
                {
                  "id": 10,
                  "title": "Critical Alerts",
                  "type": "logs",
                  "gridPos": { "h": 4, "w": 6, "x": 18, "y": 22 },
                  "targets": [
                    {
                      "expr": "{job=\"systemd-journal\"} |= \"CRITICAL\" or \"ERROR\" or \"FAILED\"",
                      "refId": "A"
                    }
                  ],
                  "options": {
                    "showTime": true,
                    "showLabels": false,
                    "showCommonLabels": false,
                    "wrapLogMessage": false,
                    "prettifyLogMessage": false,
                    "enableLogDetails": true,
                    "dedupStrategy": "none",
                    "sortOrder": "Descending"
                  }
                }
              ]
            }
          }
          EOF
          
          # Create AI Security Dashboard
          cat > "$DASHBOARD_DIR/ai-security-dashboard.json" << 'EOF'
          {
            "dashboard": {
              "id": null,
              "title": "AI Security Dashboard",
              "description": "Security monitoring for AI infrastructure",
              "tags": ["ai", "security", "monitoring", "ssh"],
              "timezone": "browser",
              "refresh": "${cfg.refreshInterval}",
              "time": {
                "from": "now-24h",
                "to": "now"
              },
              "panels": [
                {
                  "id": 1,
                  "title": "SSH Connection Attempts",
                  "type": "timeseries",
                  "gridPos": { "h": 8, "w": 12, "x": 0, "y": 0 },
                  "targets": [
                    {
                      "expr": "rate(ssh_connection_attempts_total[5m]) * 60",
                      "legendFormat": "{{instance}} SSH Attempts/min",
                      "refId": "A"
                    },
                    {
                      "expr": "rate(ssh_failed_attempts_total[5m]) * 60",
                      "legendFormat": "{{instance}} Failed Attempts/min",
                      "refId": "B"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": { "mode": "palette-classic" },
                      "unit": "short"
                    }
                  }
                },
                {
                  "id": 2,
                  "title": "Security Audit Status",
                  "type": "stat",
                  "gridPos": { "h": 8, "w": 12, "x": 12, "y": 0 },
                  "targets": [
                    {
                      "expr": "ai_security_audit_last_run",
                      "legendFormat": "Last Security Audit",
                      "refId": "A"
                    },
                    {
                      "expr": "ai_security_findings_total",
                      "legendFormat": "Total Findings",
                      "refId": "B"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": { "mode": "thresholds" },
                      "thresholds": {
                        "steps": [
                          { "color": "green", "value": 0 },
                          { "color": "yellow", "value": 5 },
                          { "color": "red", "value": 10 }
                        ]
                      }
                    }
                  }
                },
                {
                  "id": 3,
                  "title": "Fail2Ban Activity",
                  "type": "timeseries",
                  "gridPos": { "h": 8, "w": 24, "x": 0, "y": 8 },
                  "targets": [
                    {
                      "expr": "fail2ban_banned_ips_total",
                      "legendFormat": "{{instance}} Banned IPs",
                      "refId": "A"
                    },
                    {
                      "expr": "rate(fail2ban_bans_total[5m]) * 60",
                      "legendFormat": "{{instance}} New Bans/min",
                      "refId": "B"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": { "mode": "palette-classic" },
                      "unit": "short"
                    }
                  }
                }
              ]
            }
          }
          EOF
          
          # Create AI Performance Dashboard
          cat > "$DASHBOARD_DIR/ai-performance-dashboard.json" << 'EOF'
          {
            "dashboard": {
              "id": null,
              "title": "AI Performance Dashboard",
              "description": "AI system performance monitoring and optimization tracking",
              "tags": ["ai", "performance", "optimization", "providers"],
              "timezone": "browser",
              "refresh": "${cfg.refreshInterval}",
              "time": {
                "from": "now-4h",
                "to": "now"
              },
              "panels": [
                {
                  "id": 1,
                  "title": "AI Provider Performance Comparison",
                  "type": "timeseries",
                  "gridPos": { "h": 8, "w": 12, "x": 0, "y": 0 },
                  "targets": [
                    {
                      "expr": "ai_provider_response_time_ms",
                      "legendFormat": "{{provider}} Response Time",
                      "refId": "A"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": { "mode": "palette-classic" },
                      "unit": "ms",
                      "thresholds": {
                        "steps": [
                          { "color": "green", "value": 0 },
                          { "color": "yellow", "value": 5000 },
                          { "color": "red", "value": 10000 }
                        ]
                      }
                    }
                  }
                },
                {
                  "id": 2,
                  "title": "Performance Optimization History",
                  "type": "timeseries",
                  "gridPos": { "h": 8, "w": 12, "x": 12, "y": 0 },
                  "targets": [
                    {
                      "expr": "ai_performance_optimization_runs_total",
                      "legendFormat": "Optimization Runs",
                      "refId": "A"
                    },
                    {
                      "expr": "ai_performance_improvement_percent",
                      "legendFormat": "Performance Improvement %",
                      "refId": "B"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": { "mode": "palette-classic" },
                      "unit": "percent"
                    }
                  }
                },
                {
                  "id": 3,
                  "title": "Cache Performance",
                  "type": "timeseries",
                  "gridPos": { "h": 8, "w": 24, "x": 0, "y": 8 },
                  "targets": [
                    {
                      "expr": "ai_cache_hit_rate",
                      "legendFormat": "Cache Hit Rate",
                      "refId": "A"
                    },
                    {
                      "expr": "ai_cache_size_bytes",
                      "legendFormat": "Cache Size",
                      "refId": "B"
                    }
                  ],
                  "fieldConfig": {
                    "defaults": {
                      "color": { "mode": "palette-classic" },
                      "unit": "percent"
                    }
                  }
                }
              ]
            }
          }
          EOF
          
          echo "[$(date)] Production dashboards created successfully"
          
          # Set proper permissions
          chmod 644 "$DASHBOARD_DIR"/*.json
          
          # Restart Grafana if running to pick up new dashboards
          if systemctl is-active grafana &>/dev/null; then
            echo "[$(date)] Restarting Grafana to load new dashboards..."
            systemctl restart grafana
          fi
          
          echo "[$(date)] Production dashboard provisioning completed"
        '';
      };
    };

    # Production monitoring metrics collector
    systemd.services.ai-production-metrics = {
      description = "AI Production Metrics Collector";
      after = [ "network.target" ];
      wants = [ "network.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";

        ExecStart = pkgs.writeShellScript "collect-production-metrics" ''
          #!/bin/bash
          
          LOG_FILE="/var/log/ai-analysis/production-metrics.log"
          METRICS_DIR="/var/lib/ai-analysis/production-metrics"
          
          mkdir -p "$(dirname "$LOG_FILE")"
          mkdir -p "$METRICS_DIR"
          
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1
          
          echo "[$(date)] Starting production metrics collection..."
          
          # Collect AI service metrics
          TIMESTAMP=$(${pkgs.coreutils}/bin/date +%s)
          HOSTNAME=$(${pkgs.inetutils}/bin/hostname)
          
          # AI Analysis Service Metrics
          AI_SERVICES_RUNNING=$(${pkgs.systemd}/bin/systemctl list-units --type=service --state=running | ${pkgs.gnugrep}/bin/grep -c "ai-" || echo 0)
          AI_SERVICES_FAILED=$(${pkgs.systemd}/bin/systemctl list-units --type=service --state=failed | ${pkgs.gnugrep}/bin/grep -c "ai-" || echo 0)
          
          # Performance Metrics
          if command -v ai-cli &>/dev/null; then
            AI_RESPONSE_TIME=$(${pkgs.coreutils}/bin/timeout 10 time ai-cli "test" 2>&1 | ${pkgs.gnugrep}/bin/grep real | ${pkgs.gawk}/bin/awk '{print $2}' | ${pkgs.gnused}/bin/sed 's/[^0-9.]//g' || echo "0")
          else
            AI_RESPONSE_TIME="0"
          fi
          
          # Security Metrics
          SSH_FAILED_ATTEMPTS=$(${pkgs.systemd}/bin/journalctl -u sshd --since="1 hour ago" | ${pkgs.gnugrep}/bin/grep -c "Failed password" || echo 0)
          SSH_SUCCESSFUL_LOGINS=$(${pkgs.systemd}/bin/journalctl -u sshd --since="1 hour ago" | ${pkgs.gnugrep}/bin/grep -c "Accepted" || echo 0)
          
          # System Resource Metrics
          CPU_USAGE=$(${pkgs.procps}/bin/top -bn1 | ${pkgs.gnugrep}/bin/grep "Cpu(s)" | ${pkgs.gawk}/bin/awk '{print $2}' | ${pkgs.gnused}/bin/sed 's/%us,//')
          MEMORY_USAGE=$(${pkgs.procps}/bin/free | ${pkgs.gnugrep}/bin/grep Mem | ${pkgs.gawk}/bin/awk '{printf "%.1f", $3/$2 * 100.0}')
          DISK_USAGE=$(${pkgs.coreutils}/bin/df / | ${pkgs.coreutils}/bin/tail -1 | ${pkgs.gawk}/bin/awk '{print $5}' | ${pkgs.gnused}/bin/sed 's/%//')
          
          # Storage Critical Check (P510 specific)
          if [ "$HOSTNAME" = "p510" ]; then
            P510_DISK_USAGE=$(${pkgs.coreutils}/bin/df / | ${pkgs.coreutils}/bin/tail -1 | ${pkgs.gawk}/bin/awk '{print $5}' | ${pkgs.gnused}/bin/sed 's/%//')
            if [ "$P510_DISK_USAGE" -gt 75 ]; then
              echo "[$(${pkgs.coreutils}/bin/date)] CRITICAL: P510 disk usage at $P510_DISK_USAGE%"
              ${pkgs.util-linux}/bin/logger -t ai-production-metrics "CRITICAL: P510 disk usage at $P510_DISK_USAGE%"
            fi
          fi
          
          # Create metrics file
          cat > "$METRICS_DIR/metrics_$TIMESTAMP.json" << EOF
          {
            "timestamp": $TIMESTAMP,
            "hostname": "$HOSTNAME",
            "ai_services": {
              "running": $AI_SERVICES_RUNNING,
              "failed": $AI_SERVICES_FAILED,
              "response_time_ms": $AI_RESPONSE_TIME
            },
            "security": {
              "ssh_failed_attempts": $SSH_FAILED_ATTEMPTS,
              "ssh_successful_logins": $SSH_SUCCESSFUL_LOGINS
            },
            "system": {
              "cpu_usage": $CPU_USAGE,
              "memory_usage": $MEMORY_USAGE,
              "disk_usage": $DISK_USAGE
            },
            "health_status": {
              "overall": "$([ $AI_SERVICES_FAILED -eq 0 ] 2>/dev/null && echo \"healthy\" || echo \"degraded\")",
              "critical_alerts": "$([ $DISK_USAGE -gt ${toString cfg.criticalThresholds.diskUsage} ] 2>/dev/null && echo \"true\" || echo \"false\")"
            }
          }
          EOF
          
          # Cleanup old metrics (keep last 24 hours)
          ${pkgs.findutils}/bin/find "$METRICS_DIR" -name "metrics_*.json" -mtime +1 -delete
          
          echo "[$(${pkgs.coreutils}/bin/date)] Production metrics collection completed"
        '';
      };
    };

    # Dashboard health check service
    systemd.services.ai-dashboard-health = {
      description = "AI Dashboard Health Check";
      after = [ "network.target" ];
      wants = [ "network.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "dashboard-health-check" ''
          #!/bin/bash
          
          LOG_FILE="/var/log/ai-analysis/dashboard-health.log"
          GRAFANA_URL="${cfg.grafanaUrl}"
          PROMETHEUS_URL="${cfg.prometheusUrl}"
          
          mkdir -p "$(dirname "$LOG_FILE")"
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1
          
          echo "[$(date)] Starting dashboard health check..."
          
          # Check Grafana availability
          if curl -sf "$GRAFANA_URL/api/health" &>/dev/null; then
            echo "[$(date)] Grafana is healthy"
          else
            echo "[$(date)] WARNING: Grafana is not responding"
            ${pkgs.util-linux}/bin/logger -t ai-dashboard-health "WARNING: Grafana is not responding at $GRAFANA_URL"
          fi
          
          # Check Prometheus availability
          if curl -sf "$PROMETHEUS_URL/-/healthy" &>/dev/null; then
            echo "[$(date)] Prometheus is healthy"
          else
            echo "[$(date)] WARNING: Prometheus is not responding"
            ${pkgs.util-linux}/bin/logger -t ai-dashboard-health "WARNING: Prometheus is not responding at $PROMETHEUS_URL"
          fi
          
          # Check dashboard files
          DASHBOARD_COUNT=$(find "${cfg.dashboardPath}" -name "*.json" | wc -l)
          if [ "$DASHBOARD_COUNT" -gt 0 ]; then
            echo "[$(date)] Found $DASHBOARD_COUNT dashboard files"
          else
            echo "[$(date)] WARNING: No dashboard files found"
            ${pkgs.util-linux}/bin/logger -t ai-dashboard-health "WARNING: No dashboard files found in ${cfg.dashboardPath}"
          fi
          
          echo "[$(date)] Dashboard health check completed"
        '';
      };
    };

    # Timers for regular operations
    systemd.timers = {
      ai-production-dashboard = {
        description = "AI Production Dashboard Provisioner Timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
      };

      ai-production-metrics = {
        description = "AI Production Metrics Timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*:0/5"; # Every 5 minutes
          Persistent = true;
          RandomizedDelaySec = "30s";
        };
      };

      ai-dashboard-health = {
        description = "AI Dashboard Health Check Timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*:0/15"; # Every 15 minutes
          Persistent = true;
          RandomizedDelaySec = "1m";
        };
      };
    };

    # Create necessary directories
    systemd.tmpfiles.rules = [
      "d /var/lib/ai-analysis/production-metrics 0755 root root -"
      "d /var/log/ai-analysis 0755 ai-analysis ai-analysis -"
      "d ${cfg.dashboardPath} 0755 grafana grafana -"
    ];

    # Dashboard management commands
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "ai-dashboard-status" ''
        #!/bin/bash
        
        echo "=== AI Production Dashboard Status ==="
        echo
        
        echo "Dashboard Services:"
        systemctl status ai-production-dashboard --no-pager -l
        echo
        
        echo "Metrics Collection:"
        systemctl status ai-production-metrics --no-pager -l
        echo
        
        echo "Dashboard Health:"
        systemctl status ai-dashboard-health --no-pager -l
        echo
        
        echo "Available Dashboards:"
        find "${cfg.dashboardPath}" -name "*.json" -exec basename {} \; | sort
        echo
        
        echo "Recent Metrics:"
        ls -la /var/lib/ai-analysis/production-metrics/ | tail -5
        echo
        
        echo "Grafana URL: ${cfg.grafanaUrl}"
        echo "Prometheus URL: ${cfg.prometheusUrl}"
      '')

      (pkgs.writeShellScriptBin "ai-dashboard-reload" ''
        #!/bin/bash
        
        echo "Reloading AI production dashboards..."
        
        # Restart dashboard provisioner
        systemctl restart ai-production-dashboard
        
        # Restart Grafana if running
        if systemctl is-active grafana &>/dev/null; then
          echo "Restarting Grafana..."
          systemctl restart grafana
        fi
        
        echo "Dashboard reload completed"
      '')
    ];

    # Shell aliases for dashboard management
    programs.zsh.shellAliases = mkIf config.programs.zsh.enable {
      "ai-dash" = "ai-dashboard-status";
      "ai-dash-reload" = "ai-dashboard-reload";
      "ai-metrics" = "systemctl start ai-production-metrics";
    };
  };
}
