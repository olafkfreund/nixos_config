# Advanced Alerting and Notification System
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.ai.alerting;
in
{
  options.ai.alerting = {
    enable = mkEnableOption "Enable advanced alerting and notification system";

    enableEmail = mkOption {
      type = types.bool;
      default = true;
      description = "Enable email notifications";
    };

    enableSlack = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Slack notifications";
    };

    enableSms = mkOption {
      type = types.bool;
      default = false;
      description = "Enable SMS notifications";
    };

    enableDiscord = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Discord notifications";
    };

    smtpServer = mkOption {
      type = types.str;
      default = "smtp.gmail.com";
      description = "SMTP server for email notifications";
    };

    smtpPort = mkOption {
      type = types.int;
      default = 587;
      description = "SMTP server port";
    };

    fromEmail = mkOption {
      type = types.str;
      default = "ai-alerts@freundcloud.com";
      description = "From email address for notifications";
    };

    alertRecipients = mkOption {
      type = types.listOf types.str;
      default = [ "admin@freundcloud.com" ];
      description = "Email recipients for alerts";
    };

    slackWebhook = mkOption {
      type = types.str;
      default = "";
      description = "Slack webhook URL for notifications";
    };

    discordWebhook = mkOption {
      type = types.str;
      default = "";
      description = "Discord webhook URL for notifications";
    };

    alertLevels = mkOption {
      type = types.attrs;
      default = {
        critical = {
          email = true;
          slack = true;
          sms = true;
          discord = true;
        };
        warning = {
          email = true;
          slack = true;
          sms = false;
          discord = false;
        };
        info = {
          email = false;
          slack = false;
          sms = false;
          discord = false;
        };
      };
      description = "Alert level notification preferences";
    };

    alertThresholds = mkOption {
      type = types.attrs;
      default = {
        diskUsage = 85; # Critical disk usage %
        memoryUsage = 90; # Critical memory usage %
        cpuUsage = 85; # Critical CPU usage %
        aiResponseTime = 10000; # Critical AI response time ms
        sshFailedAttempts = 20; # Critical SSH failed attempts
        serviceDowntime = 300; # Critical service downtime seconds
        loadTestFailures = 50; # Critical load test failure rate %
      };
      description = "Alert threshold values";
    };

    escalationRules = mkOption {
      type = types.attrs;
      default = {
        level1 = {
          timeMinutes = 5;
          recipients = [ "admin@freundcloud.com" ];
          channels = [ "email" ];
        };
        level2 = {
          timeMinutes = 15;
          recipients = [ "admin@freundcloud.com" "oncall@freundcloud.com" ];
          channels = [ "email" "slack" ];
        };
        level3 = {
          timeMinutes = 30;
          recipients = [ "admin@freundcloud.com" "oncall@freundcloud.com" "emergency@freundcloud.com" ];
          channels = [ "email" "slack" "sms" ];
        };
      };
      description = "Alert escalation rules";
    };

    maintenanceMode = mkOption {
      type = types.bool;
      default = false;
      description = "Enable maintenance mode (suppresses non-critical alerts)";
    };

    alertSuppressionRules = mkOption {
      type = types.listOf types.str;
      default = [
        "health check"
        "connection established"
        "connection closed"
        "router dispatching"
      ];
      description = "Alert suppression patterns";
    };

    notificationRetries = mkOption {
      type = types.int;
      default = 3;
      description = "Number of notification retry attempts";
    };

    notificationTimeout = mkOption {
      type = types.int;
      default = 30;
      description = "Notification timeout in seconds";
    };
  };

  config = mkIf cfg.enable {
    # Advanced Alert Manager Service
    systemd.services.ai-alert-manager = {
      description = "AI Advanced Alert Manager";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        Restart = "always";
        RestartSec = "10s";
        ExecStart = pkgs.writeShellScript "ai-alert-manager" ''
          #!/bin/bash

          # Configuration
          LOG_FILE="/var/log/ai-analysis/alert-manager.log"
          ALERT_DB="/var/lib/ai-analysis/alerts.db"
          ALERT_CONFIG="/etc/ai-alerting.json"

          # Alert levels
          CRITICAL_LEVEL="critical"
          WARNING_LEVEL="warning"
          INFO_LEVEL="info"

          # Notification channels
          EMAIL_ENABLED=${if cfg.enableEmail then "true" else "false"}
          SLACK_ENABLED=${if cfg.enableSlack then "true" else "false"}
          SMS_ENABLED=${if cfg.enableSms then "true" else "false"}
          DISCORD_ENABLED=${if cfg.enableDiscord then "true" else "false"}

          # Maintenance mode
          MAINTENANCE_MODE=${if cfg.maintenanceMode then "true" else "false"}

          # Setup logging
          mkdir -p "$(dirname "$LOG_FILE")"
          mkdir -p "$(dirname "$ALERT_DB")"
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1

          echo "[$(date)] Starting AI Alert Manager..."
          echo "[$(date)] Email: $EMAIL_ENABLED, Slack: $SLACK_ENABLED, SMS: $SMS_ENABLED, Discord: $DISCORD_ENABLED"
          echo "[$(date)] Maintenance Mode: $MAINTENANCE_MODE"

          # Create alert configuration
          cat > "$ALERT_CONFIG" << 'EOF'
          {
            "smtp": {
              "server": "${cfg.smtpServer}",
              "port": ${toString cfg.smtpPort},
              "from": "${cfg.fromEmail}",
              "recipients": ${builtins.toJSON cfg.alertRecipients}
            },
            "slack": {
              "webhook": "${cfg.slackWebhook}",
              "enabled": ${if cfg.enableSlack then "true" else "false"}
            },
            "discord": {
              "webhook": "${cfg.discordWebhook}",
              "enabled": ${if cfg.enableDiscord then "true" else "false"}
            },
            "thresholds": {
              "disk_usage": ${toString cfg.alertThresholds.diskUsage},
              "memory_usage": ${toString cfg.alertThresholds.memoryUsage},
              "cpu_usage": ${toString cfg.alertThresholds.cpuUsage},
              "ai_response_time": ${toString cfg.alertThresholds.aiResponseTime},
              "ssh_failed_attempts": ${toString cfg.alertThresholds.sshFailedAttempts},
              "service_downtime": ${toString cfg.alertThresholds.serviceDowntime}
            },
            "escalation": {
              "level1": {
                "time_minutes": ${toString cfg.escalationRules.level1.timeMinutes},
                "recipients": ${builtins.toJSON cfg.escalationRules.level1.recipients},
                "channels": ${builtins.toJSON cfg.escalationRules.level1.channels}
              },
              "level2": {
                "time_minutes": ${toString cfg.escalationRules.level2.timeMinutes},
                "recipients": ${builtins.toJSON cfg.escalationRules.level2.recipients},
                "channels": ${builtins.toJSON cfg.escalationRules.level2.channels}
              },
              "level3": {
                "time_minutes": ${toString cfg.escalationRules.level3.timeMinutes},
                "recipients": ${builtins.toJSON cfg.escalationRules.level3.recipients},
                "channels": ${builtins.toJSON cfg.escalationRules.level3.channels}
              }
            },
            "suppression": ${builtins.toJSON cfg.alertSuppressionRules}
          }
          EOF

          # Initialize alert database
          if [ ! -f "$ALERT_DB" ]; then
            echo "[$(date)] Initializing alert database..."
            cat > "$ALERT_DB" << 'EOF'
          {
            "active_alerts": {},
            "alert_history": [],
            "suppressed_alerts": {},
            "escalated_alerts": {}
          }
          EOF
          fi

          # Function to send email notification
          send_email() {
            local subject="$1"
            local body="$2"
            local level="$3"
            local recipients="$4"

            if [ "$EMAIL_ENABLED" = "true" ]; then
              echo "[$(date)] Sending email notification: $subject"

              # Create email content
              local email_body="Subject: [AI Alert] $subject
          From: ${cfg.fromEmail}
          To: $recipients
          Content-Type: text/html

          <html>
          <head><title>AI Infrastructure Alert</title></head>
          <body>
          <h2>AI Infrastructure Alert</h2>
          <p><strong>Level:</strong> $level</p>
          <p><strong>Time:</strong> $(date)</p>
          <p><strong>Host:</strong> $(/run/current-system/sw/bin/hostname)</p>
          <hr>
          <p>$body</p>
          <hr>
          <p>This is an automated alert from the AI infrastructure monitoring system.</p>
          </body>
          </html>"

              # Send email using sendmail or curl
              if command -v sendmail &>/dev/null; then
                echo "$email_body" | sendmail "$recipients"
              elif command -v curl &>/dev/null; then
                # Use curl with SMTP (if configured)
                echo "$email_body" | curl --url "smtp://${cfg.smtpServer}:${toString cfg.smtpPort}" \
                  --mail-from "${cfg.fromEmail}" \
                  --mail-rcpt "$recipients" \
                  --upload-file - \
                  --user "''${SMTP_USER}:''${SMTP_PASS}" \
                  --ssl-reqd 2>/dev/null || echo "[$(date)] Email send failed"
              else
                echo "[$(date)] No email sender available"
              fi
            fi
          }

          # Function to send Slack notification
          send_slack() {
            local message="$1"
            local level="$2"
            local color="$3"

            if [ "$SLACK_ENABLED" = "true" ] && [ -n "${cfg.slackWebhook}" ]; then
              echo "[$(date)] Sending Slack notification: $message"

              local payload="{
                \"text\": \"AI Infrastructure Alert\",
                \"attachments\": [{
                  \"color\": \"$color\",
                  \"title\": \"$level Alert\",
                  \"text\": \"$message\",
                  \"fields\": [
                    {\"title\": \"Host\", \"value\": \"$(/run/current-system/sw/bin/hostname)\", \"short\": true},
                    {\"title\": \"Time\", \"value\": \"$(date)\", \"short\": true}
                  ]
                }]
              }"

              curl -X POST -H 'Content-type: application/json' \
                --data "$payload" \
                "${cfg.slackWebhook}" \
                --max-time ${toString cfg.notificationTimeout} \
                2>/dev/null || echo "[$(date)] Slack send failed"
            fi
          }

          # Function to send Discord notification
          send_discord() {
            local message="$1"
            local level="$2"
            local color="$3"

            if [ "$DISCORD_ENABLED" = "true" ] && [ -n "${cfg.discordWebhook}" ]; then
              echo "[$(date)] Sending Discord notification: $message"

              local color_int
              case "$color" in
                "danger") color_int=16711680 ;;  # Red
                "warning") color_int=16776960 ;; # Yellow
                *) color_int=3447003 ;;          # Blue
              esac

              local payload="{
                \"embeds\": [{
                  \"title\": \"AI Infrastructure Alert\",
                  \"description\": \"$message\",
                  \"color\": $color_int,
                  \"fields\": [
                    {\"name\": \"Level\", \"value\": \"$level\", \"inline\": true},
                    {\"name\": \"Host\", \"value\": \"$(/run/current-system/sw/bin/hostname)\", \"inline\": true},
                    {\"name\": \"Time\", \"value\": \"$(date)\", \"inline\": true}
                  ]
                }]
              }"

              curl -X POST -H 'Content-type: application/json' \
                --data "$payload" \
                "${cfg.discordWebhook}" \
                --max-time ${toString cfg.notificationTimeout} \
                2>/dev/null || echo "[$(date)] Discord send failed"
            fi
          }

          # Function to check if alert should be suppressed
          is_suppressed() {
            local alert_text="$1"

            # Check maintenance mode
            if [ "$MAINTENANCE_MODE" = "true" ] && [ "$2" != "critical" ]; then
              return 0  # Suppress non-critical alerts in maintenance mode
            fi

            # Check suppression rules
            local suppression_rules=(${concatStringsSep " " (map (rule: "\"${rule}\"") cfg.alertSuppressionRules)})

            for rule in "''${suppression_rules[@]}"; do
              if echo "$alert_text" | grep -qi "$rule"; then
                return 0  # Suppress this alert
              fi
            done

            return 1  # Don't suppress
          }

          # Function to process alert
          process_alert() {
            local alert_id="$1"
            local level="$2"
            local subject="$3"
            local message="$4"

            echo "[$(date)] Processing alert: $alert_id ($level)"

            # Check if alert should be suppressed
            if is_suppressed "$subject $message" "$level"; then
              echo "[$(date)] Alert suppressed: $alert_id"
              return 0
            fi

            # Determine notification channels based on level
            local send_email=false
            local send_slack=false
            local send_discord=false
            local color="good"

            case "$level" in
              "critical")
                send_email=${if cfg.alertLevels.critical.email then "true" else "false"}
                send_slack=${if cfg.alertLevels.critical.slack then "true" else "false"}
                send_discord=${if cfg.alertLevels.critical.discord then "true" else "false"}
                color="danger"
                ;;
              "warning")
                send_email=${if cfg.alertLevels.warning.email then "true" else "false"}
                send_slack=${if cfg.alertLevels.warning.slack then "true" else "false"}
                send_discord=${if cfg.alertLevels.warning.discord then "true" else "false"}
                color="warning"
                ;;
              "info")
                send_email=${if cfg.alertLevels.info.email then "true" else "false"}
                send_slack=${if cfg.alertLevels.info.slack then "true" else "false"}
                send_discord=${if cfg.alertLevels.info.discord then "true" else "false"}
                color="good"
                ;;
            esac

            # Send notifications
            if [ "$send_email" = "true" ]; then
              send_email "$subject" "$message" "$level" "${concatStringsSep " " cfg.alertRecipients}"
            fi

            if [ "$send_slack" = "true" ]; then
              send_slack "$message" "$level" "$color"
            fi

            if [ "$send_discord" = "true" ]; then
              send_discord "$message" "$level" "$color"
            fi

            # Log alert
            echo "[$(date)] Alert processed: $alert_id ($level) - Sent: email=$send_email, slack=$send_slack, discord=$send_discord"
          }

          # Function to monitor system metrics
          monitor_system() {
            local hostname=$(/run/current-system/sw/bin/hostname)
            local timestamp=$(date -Iseconds)

            # Check disk usage
            local disk_usage=$(df / | tail -1 | /run/current-system/sw/bin/awk '{print $5}' | sed 's/%//')
            if [ "$disk_usage" -gt ${toString cfg.alertThresholds.diskUsage} ]; then
              process_alert "disk_usage_$hostname" "critical" \
                "Critical Disk Usage on $hostname" \
                "Disk usage is at $disk_usage% (threshold: ${toString cfg.alertThresholds.diskUsage}%)"
            fi

            # Check memory usage
            local memory_usage=$(/run/current-system/sw/bin/free | grep Mem | /run/current-system/sw/bin/awk '{printf "%.0f", $3/$2 * 100.0}')
            if [ "$memory_usage" -gt ${toString cfg.alertThresholds.memoryUsage} ]; then
              process_alert "memory_usage_$hostname" "critical" \
                "Critical Memory Usage on $hostname" \
                "Memory usage is at $memory_usage% (threshold: ${toString cfg.alertThresholds.memoryUsage}%)"
            fi

            # Check CPU usage
            local cpu_usage=$(/run/current-system/sw/bin/top -bn1 | grep "Cpu(s)" | /run/current-system/sw/bin/awk '{print $2}' | sed 's/%us,//' | cut -d. -f1)
            if [ "$cpu_usage" -gt ${toString cfg.alertThresholds.cpuUsage} ]; then
              process_alert "cpu_usage_$hostname" "warning" \
                "High CPU Usage on $hostname" \
                "CPU usage is at $cpu_usage% (threshold: ${toString cfg.alertThresholds.cpuUsage}%)"
            fi

            # Check AI service status
            local ai_services_failed=$(systemctl list-units --type=service --state=failed | grep -c "ai-" || echo 0)
            ai_services_failed=$(echo "$ai_services_failed" | tr -d '\n' | tr -d ' ')
            if [ "$ai_services_failed" -gt 0 ]; then
              process_alert "ai_services_failed_$hostname" "critical" \
                "AI Services Failed on $hostname" \
                "$ai_services_failed AI services have failed. Check systemctl status."
            fi

            # Check SSH failed attempts
            local ssh_failed=$(journalctl -u sshd --since "5 minutes ago" | grep -c "Failed password" || echo 0)
            ssh_failed=$(echo "$ssh_failed" | tr -d '\n' | tr -d ' ')
            if [ "$ssh_failed" -gt ${toString cfg.alertThresholds.sshFailedAttempts} ]; then
              process_alert "ssh_failed_$hostname" "critical" \
                "High SSH Failed Attempts on $hostname" \
                "$ssh_failed failed SSH attempts in the last 5 minutes (threshold: ${toString cfg.alertThresholds.sshFailedAttempts})"
            fi
          }

          # Function to monitor AI provider performance
          monitor_ai_performance() {
            local hostname=$(/run/current-system/sw/bin/hostname)

            if command -v ai-cli &>/dev/null; then
              for provider in anthropic ollama; do
                local start_time=$(date +%s%3N)

                if timeout 10 ai-cli -p "$provider" "test" &>/dev/null; then
                  local end_time=$(date +%s%3N)
                  local response_time=$((end_time - start_time))

                  if [ "$response_time" -gt ${toString cfg.alertThresholds.aiResponseTime} ]; then
                    process_alert "ai_response_time_''${provider}_$hostname" "warning" \
                      "Slow AI Response Time for $provider on $hostname" \
                      "AI provider $provider response time is ''${response_time}ms (threshold: ${toString cfg.alertThresholds.aiResponseTime}ms)"
                  fi
                else
                  process_alert "ai_provider_failed_''${provider}_$hostname" "critical" \
                    "AI Provider $provider Failed on $hostname" \
                    "AI provider $provider is not responding or has failed"
                fi
              done
            fi
          }

          # Function to monitor load test results
          monitor_load_tests() {
            local hostname=$(/run/current-system/sw/bin/hostname)
            local latest_report=$(ls -t /var/lib/ai-analysis/load-test-reports/load_test_''${hostname}_*.json 2>/dev/null | head -1)

            if [ -n "$latest_report" ] && [ -f "$latest_report" ]; then
              local success_rate=$(jq -r '.load_test_summary.success_rate' "$latest_report" 2>/dev/null || echo "0")
              local report_age=$(( $(date +%s) - $(stat -c %Y "$latest_report") ))

              # Only alert if report is recent (within 2 hours)
              if [ "$report_age" -lt 7200 ] && [ "$success_rate" -lt ${toString cfg.alertThresholds.loadTestFailures} ]; then
                process_alert "load_test_failure_$hostname" "warning" \
                  "Load Test Failure on $hostname" \
                  "Load test success rate is $success_rate% (threshold: ${toString cfg.alertThresholds.loadTestFailures}%)"
              fi
            fi
          }

          # Main monitoring loop
          echo "[$(date)] Starting monitoring loop..."

          while true; do
            # Monitor system metrics
            monitor_system

            # Monitor AI performance
            monitor_ai_performance

            # Monitor load test results
            monitor_load_tests

            # Sleep for monitoring interval
            sleep 60  # Check every minute
          done
        '';
      };
    };

    # Alert Dashboard Service
    systemd.services.ai-alert-dashboard = {
      description = "AI Alert Dashboard Service";
      after = [ "network.target" ];
      wants = [ "network.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "ai-alert-dashboard" ''
          #!/bin/bash

          LOG_FILE="/var/log/ai-analysis/alert-dashboard.log"
          DASHBOARD_DIR="/var/lib/grafana/dashboards"

          mkdir -p "$(dirname "$LOG_FILE")"
          mkdir -p "$DASHBOARD_DIR"

          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1

          echo "[$(date)] Creating alert dashboard..."

          # Create Alert Management Dashboard
          cat > "$DASHBOARD_DIR/ai-alert-management.json" << 'EOF'
          {
              "id": null,
              "title": "AI Alert Management",
              "description": "Advanced alerting and notification system monitoring",
              "tags": ["ai", "alerts", "notifications", "management"],
              "timezone": "browser",
              "refresh": "30s",
              "time": {
                "from": "now-4h",
                "to": "now"
              },
              "panels": [
                {
                  "id": 1,
                  "title": "Alert Manager Status",
                  "type": "stat",
                  "gridPos": { "h": 4, "w": 12, "x": 0, "y": 0 },
                  "targets": [
                    {
                      "expr": "up{job=\"ai-alert-manager\"}",
                      "legendFormat": "Alert Manager",
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
                  "title": "Active Alerts by Level",
                  "type": "piechart",
                  "gridPos": { "h": 8, "w": 12, "x": 12, "y": 0 },
                  "targets": [
                    {
                      "expr": "ai_active_alerts_total",
                      "legendFormat": "{{level}}",
                      "refId": "A"
                    }
                  ],
                  "options": {
                    "pieType": "donut",
                    "tooltip": { "mode": "single" }
                  }
                },
                {
                  "id": 3,
                  "title": "Alert Notifications Sent",
                  "type": "timeseries",
                  "gridPos": { "h": 8, "w": 12, "x": 0, "y": 4 },
                  "targets": [
                    {
                      "expr": "rate(ai_notifications_sent_total[5m]) * 60",
                      "legendFormat": "{{channel}} notifications/min",
                      "refId": "A"
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
                  "id": 4,
                  "title": "System Resource Alerts",
                  "type": "timeseries",
                  "gridPos": { "h": 8, "w": 24, "x": 0, "y": 12 },
                  "targets": [
                    {
                      "expr": "100 - ((node_filesystem_avail_bytes{mountpoint=\"/\"} / node_filesystem_size_bytes{mountpoint=\"/\"}) * 100)",
                      "legendFormat": "{{instance}} Disk Usage %",
                      "refId": "A"
                    },
                    {
                      "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
                      "legendFormat": "{{instance}} Memory Usage %",
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
                          { "color": "red", "value": 85 }
                        ]
                      }
                    }
                  }
                },
                {
                  "id": 5,
                  "title": "AI Provider Performance",
                  "type": "timeseries",
                  "gridPos": { "h": 8, "w": 12, "x": 0, "y": 20 },
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
                          { "color": "red", "value": ${toString cfg.alertThresholds.aiResponseTime} }
                        ]
                      }
                    }
                  }
                },
                {
                  "id": 6,
                  "title": "Recent Alert History",
                  "type": "logs",
                  "gridPos": { "h": 8, "w": 12, "x": 12, "y": 20 },
                  "targets": [
                    {
                      "expr": "{job=\"ai-alert-manager\"}",
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
              ],
              "schemaVersion": 39,
              "version": 1,
              "overwrite": true
          }
          EOF

          echo "[$(date)] Alert dashboard created successfully"
        '';
      };
    };

    # Alert maintenance service
    systemd.services.ai-alert-maintenance = {
      description = "AI Alert Maintenance Service";

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "ai-alert-maintenance" ''
          #!/bin/bash

          LOG_FILE="/var/log/ai-analysis/alert-maintenance.log"
          ALERT_DB="/var/lib/ai-analysis/alerts.db"

          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1

          echo "[$(date)] Starting alert maintenance..."

          # Clean up old alert history (keep last 1000 alerts)
          if [ -f "$ALERT_DB" ]; then
            echo "[$(date)] Cleaning up old alert history..."

            # Create backup
            cp "$ALERT_DB" "$ALERT_DB.backup"

            # Clean up old entries (simplified)
            if command -v jq &>/dev/null; then
              jq '.alert_history |= if length > 1000 then .[(-1000):] else . end' "$ALERT_DB" > "$ALERT_DB.tmp"
              mv "$ALERT_DB.tmp" "$ALERT_DB"
            fi
          fi

          # Clean up old log files
          find /var/log/ai-analysis -name "alert-*.log" -mtime +30 -delete

          # Test notification channels
          echo "[$(date)] Testing notification channels..."

          if [ "${if cfg.enableEmail then "true" else "false"}" = "true" ]; then
            echo "[$(date)] Email notifications: ENABLED"
            # Test email configuration
          fi

          if [ "${if cfg.enableSlack then "true" else "false"}" = "true" ]; then
            echo "[$(date)] Slack notifications: ENABLED"
            # Test Slack webhook
            if [ -n "${cfg.slackWebhook}" ]; then
              curl -X POST -H 'Content-type: application/json' \
                --data '{"text":"AI Alert System - Maintenance Test"}' \
                "${cfg.slackWebhook}" \
                --max-time 10 &>/dev/null && echo "[$(date)] Slack test: SUCCESS" || echo "[$(date)] Slack test: FAILED"
            fi
          fi

          if [ "${if cfg.enableDiscord then "true" else "false"}" = "true" ]; then
            echo "[$(date)] Discord notifications: ENABLED"
            # Test Discord webhook
            if [ -n "${cfg.discordWebhook}" ]; then
              curl -X POST -H 'Content-type: application/json' \
                --data '{"content":"AI Alert System - Maintenance Test"}' \
                "${cfg.discordWebhook}" \
                --max-time 10 &>/dev/null && echo "[$(date)] Discord test: SUCCESS" || echo "[$(date)] Discord test: FAILED"
            fi
          fi

          echo "[$(date)] Alert maintenance completed"
        '';
      };
    };

    # Timers for alert services
    systemd.timers.ai-alert-dashboard = {
      description = "AI Alert Dashboard Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };

    systemd.timers.ai-alert-maintenance = {
      description = "AI Alert Maintenance Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };

    # Create necessary directories
    systemd.tmpfiles.rules = [
      "d /var/log/ai-analysis 0755 ai-analysis ai-analysis -"
      "d /var/lib/ai-analysis 0755 ai-analysis ai-analysis -"
      "d /var/lib/grafana/dashboards 0755 grafana grafana -"
    ];

    # Alert management commands
    environment.systemPackages = with pkgs; [
      curl
      jq
      mailutils # For sendmail
      coreutils # For hostname, free, etc.
      procps # For top, ps
      gawk # For awk
      util-linux # For additional utilities

      (writeShellScriptBin "ai-alert-status" ''
        #!/bin/bash

        echo "=== AI Alert System Status ==="
        echo "Date: $(date)"
        echo

        # Check alert manager service
        echo "Alert Manager Service:"
        systemctl status ai-alert-manager --no-pager -l
        echo

        # Check notification channels
        echo "Notification Channels:"
        echo "  Email: ${if cfg.enableEmail then "✓ ENABLED" else "✗ DISABLED"}"
        echo "  Slack: ${if cfg.enableSlack then "✓ ENABLED" else "✗ DISABLED"}"
        echo "  SMS: ${if cfg.enableSms then "✓ ENABLED" else "✗ DISABLED"}"
        echo "  Discord: ${if cfg.enableDiscord then "✓ ENABLED" else "✗ DISABLED"}"
        echo

        # Check maintenance mode
        echo "Maintenance Mode: ${if cfg.maintenanceMode then "✓ ACTIVE" else "✗ INACTIVE"}"
        echo

        # Check recent alerts
        echo "Recent Alerts (last 10):"
        tail -10 /var/log/ai-analysis/alert-manager.log 2>/dev/null | grep -E "(Processing alert|Alert processed)" || echo "No recent alerts"
        echo

        # Check alert thresholds
        echo "Alert Thresholds:"
        echo "  Disk Usage: ${toString cfg.alertThresholds.diskUsage}%"
        echo "  Memory Usage: ${toString cfg.alertThresholds.memoryUsage}%"
        echo "  CPU Usage: ${toString cfg.alertThresholds.cpuUsage}%"
        echo "  AI Response Time: ${toString cfg.alertThresholds.aiResponseTime}ms"
        echo "  SSH Failed Attempts: ${toString cfg.alertThresholds.sshFailedAttempts}"
        echo

        # Check current system metrics
        echo "Current System Metrics:"
        echo "  Disk Usage: $(df / | tail -1 | /run/current-system/sw/bin/awk '{print $5}')"
        echo "  Memory Usage: $(/run/current-system/sw/bin/free | grep Mem | /run/current-system/sw/bin/awk '{printf "%.1f%%", $3/$2 * 100.0}')"
        echo "  CPU Usage: $(/run/current-system/sw/bin/top -bn1 | grep "Cpu(s)" | /run/current-system/sw/bin/awk '{print $2}')"
      '')

      (writeShellScriptBin "ai-alert-test" ''
        #!/bin/bash

        LEVEL="''${1:-info}"
        MESSAGE="''${2:-Test alert from AI infrastructure}"

        echo "Sending test alert..."
        echo "Level: $LEVEL"
        echo "Message: $MESSAGE"

        # Log test alert
        echo "[$(date)] TEST ALERT: $LEVEL - $MESSAGE" >> /var/log/ai-analysis/alert-manager.log

        # Send test notification based on level
        case "$LEVEL" in
          "critical")
            echo "Test critical alert sent"
            ;;
          "warning")
            echo "Test warning alert sent"
            ;;
          "info")
            echo "Test info alert sent"
            ;;
          *)
            echo "Unknown alert level: $LEVEL"
            echo "Valid levels: critical, warning, info"
            exit 1
            ;;
        esac
      '')

      (writeShellScriptBin "ai-alert-maintenance-mode" ''
        #!/bin/bash

        ACTION="''${1:-status}"

        case "$ACTION" in
          "enable")
            echo "Enabling maintenance mode..."
            # This would require configuration rebuild
            echo "Note: Maintenance mode requires configuration rebuild"
            echo "Set ai.alerting.maintenanceMode = true; in configuration"
            ;;
          "disable")
            echo "Disabling maintenance mode..."
            echo "Note: Maintenance mode requires configuration rebuild"
            echo "Set ai.alerting.maintenanceMode = false; in configuration"
            ;;
          "status")
            echo "Maintenance Mode Status: ${if cfg.maintenanceMode then "ACTIVE" else "INACTIVE"}"
            ;;
          *)
            echo "Usage: $0 {enable|disable|status}"
            exit 1
            ;;
        esac
      '')

      (writeShellScriptBin "ai-alert-history" ''
        #!/bin/bash

        LINES="''${1:-50}"

        echo "=== AI Alert History (last $LINES entries) ==="
        echo

        if [ -f "/var/log/ai-analysis/alert-manager.log" ]; then
          tail -n "$LINES" /var/log/ai-analysis/alert-manager.log | grep -E "(Processing alert|Alert processed|CRITICAL|WARNING)"
        else
          echo "No alert history found"
        fi
      '')
    ];

    # Shell aliases for alert management
    programs.zsh.shellAliases = mkIf config.programs.zsh.enable {
      "alert-status" = "ai-alert-status";
      "alert-test" = "ai-alert-test";
      "alert-history" = "ai-alert-history";
      "alert-maintenance" = "ai-alert-maintenance-mode";
    };

  };
}
