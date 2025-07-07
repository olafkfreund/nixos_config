{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.monitoring;
in {
  config = mkIf (cfg.enable && cfg.features.alerting && (cfg.mode == "server" || cfg.mode == "standalone")) {
    services.prometheus.alertmanager = {
      enable = true;
      port = cfg.network.alertmanagerPort;
      listenAddress = "0.0.0.0";
      
      configuration = {
        global = {
          smtp_smarthost = "localhost:587";
          smtp_from = "alertmanager@${cfg.serverHost}";
        };

        route = {
          group_by = [ "alertname" "cluster" "service" ];
          group_wait = "10s";
          group_interval = "10s";
          repeat_interval = "1h";
          receiver = "default";
          
          routes = [
            {
              match = {
                severity = "critical";
              };
              receiver = "critical";
              group_wait = "5s";
              repeat_interval = "5m";
            }
            {
              match = {
                severity = "warning";
              };
              receiver = "warning";
              repeat_interval = "30m";
            }
          ];
        };

        receivers = [
          {
            name = "default";
            webhook_configs = [{
              url = "http://localhost:9094/webhook";
              send_resolved = true;
            }];
          }
          
          {
            name = "critical";
            webhook_configs = [{
              url = "http://localhost:9094/webhook/critical";
              send_resolved = true;
            }];
          }
          
          {
            name = "warning";  
            webhook_configs = [{
              url = "http://localhost:9094/webhook/warning";
              send_resolved = true;
            }];
          }
        ];

        inhibit_rules = [
          {
            source_match = {
              severity = "critical";
            };
            target_match = {
              severity = "warning";
            };
            equal = [ "alertname" "cluster" "service" ];
          }
        ];
      };
    };

    # Simple webhook receiver for alerts
    systemd.services.alert-webhook = {
      description = "Simple webhook receiver for alerts";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "simple";
        User = "monitoring";
        Group = "monitoring";
        ExecStart = pkgs.writeShellScript "alert-webhook" ''
          #!/bin/bash
          
          # Simple webhook server for receiving alerts
          PORT=9094
          
          log_alert() {
            local severity="$1"
            local timestamp=$(date -Iseconds)
            echo "[$timestamp] [$severity] Alert received" >> /var/log/monitoring/alerts.log
            
            # Parse JSON payload if available
            if [[ -p /dev/stdin ]]; then
              cat > /tmp/alert-$$.json
              echo "[$timestamp] Alert payload:" >> /var/log/monitoring/alerts.log
              cat /tmp/alert-$$.json >> /var/log/monitoring/alerts.log
              rm -f /tmp/alert-$$.json
            fi
          }
          
          # Create log directory
          mkdir -p /var/log/monitoring
          
          echo "Starting alert webhook server on port $PORT"
          
          while true; do
            {
              read -r request
              read -r headers
              
              # Simple routing based on path
              if [[ "$request" == *"/webhook/critical"* ]]; then
                echo -e "HTTP/1.1 200 OK\r\n\r\nCritical alert received"
                log_alert "CRITICAL"
              elif [[ "$request" == *"/webhook/warning"* ]]; then
                echo -e "HTTP/1.1 200 OK\r\n\r\nWarning alert received"
                log_alert "WARNING"
              elif [[ "$request" == *"/webhook"* ]]; then
                echo -e "HTTP/1.1 200 OK\r\n\r\nAlert received"
                log_alert "INFO"
              else
                echo -e "HTTP/1.1 404 Not Found\r\n\r\nNot found"
              fi
            } | ${pkgs.netcat}/bin/nc -l -p $PORT -q 1
          done
        '';
        Restart = "always";
        RestartSec = "10s";
      };
    };

    # Alert management tools
    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "alert-status" ''
        echo "Alertmanager Status"
        echo "=================="
        echo "URL: http://${cfg.serverHost}:${toString cfg.network.alertmanagerPort}"
        echo ""
        echo "Service status:"
        systemctl status alertmanager --no-pager -l
        echo ""
        echo "Active alerts:"
        ${curl}/bin/curl -s "http://localhost:${toString cfg.network.alertmanagerPort}/api/v1/alerts" | \
          ${jq}/bin/jq '.data[] | {alertname: .labels.alertname, instance: .labels.instance, status: .status.state}'
      '')

      (writeShellScriptBin "alert-logs" ''
        echo "Recent Alert Logs"
        echo "================"
        if [[ -f /var/log/monitoring/alerts.log ]]; then
          tail -50 /var/log/monitoring/alerts.log
        else
          echo "No alert logs found"
        fi
      '')

      (writeShellScriptBin "test-alert" ''
        # Send a test alert to Prometheus
        echo "Sending test alert..."
        ${curl}/bin/curl -X POST "http://localhost:${toString cfg.network.prometheusPort}/api/v1/alerts" \
          -H "Content-Type: application/json" \
          -d '[{
            "labels": {
              "alertname": "TestAlert",
              "instance": "localhost",
              "severity": "warning"
            },
            "annotations": {
              "summary": "This is a test alert",
              "description": "Test alert generated manually"
            }
          }]'
        echo "Test alert sent"
      '')
    ];

    # Open firewall port for alertmanager
    networking.firewall.allowedTCPPorts = [ cfg.network.alertmanagerPort 9094 ];
  };
}