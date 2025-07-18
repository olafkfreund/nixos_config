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
              url = "http://localhost:9097/webhook";
              send_resolved = true;
            }];
          }
          
          {
            name = "critical";
            webhook_configs = [{
              url = "http://localhost:9097/webhook/critical";
              send_resolved = true;
            }];
          }
          
          {
            name = "warning";  
            webhook_configs = [{
              url = "http://localhost:9097/webhook/warning";
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
          
          # Simple webhook server for receiving alerts using Python HTTP server
          PORT=9097
          
          log_alert() {
            local severity="$1"
            local timestamp=$(date -Iseconds)
            echo "[$timestamp] [$severity] Alert received" >> /var/log/monitoring/alerts.log
          }
          
          # Create log directory
          mkdir -p /var/log/monitoring
          
          echo "Starting alert webhook server on port $PORT"
          
          # Use Python HTTP server for more reliable webhook handling
          ${pkgs.python3}/bin/python3 -c "
import http.server
import socketserver
import urllib.parse
import json
from datetime import datetime

class AlertWebhookHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Disable default logging to avoid spam
        pass
        
    def do_POST(self):
        if self.path.startswith('/webhook'):
            try:
                content_length = int(self.headers.get('Content-Length', 0))
                if content_length > 0:
                    post_data = self.rfile.read(content_length)
                    try:
                        payload = json.loads(post_data.decode('utf-8'))
                    except:
                        payload = post_data.decode('utf-8')
                
                # Determine severity from path
                if '/critical' in self.path:
                    severity = 'CRITICAL'
                elif '/warning' in self.path:
                    severity = 'WARNING'
                else:
                    severity = 'INFO'
                
                # Log alert
                timestamp = datetime.now().isoformat()
                with open('/var/log/monitoring/alerts.log', 'a') as f:
                    f.write(f'[{timestamp}] [{severity}] Alert received\\n')
                    if content_length > 0:
                        f.write(f'[{timestamp}] Payload: {str(payload)}\\n')
                
                # Send response
                self.send_response(200)
                self.send_header('Content-type', 'text/plain')
                self.end_headers()
                self.wfile.write(f'{severity} alert received\\n'.encode())
                
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-type', 'text/plain')
                self.end_headers()
                self.wfile.write(f'Error: {str(e)}\\n'.encode())
        else:
            self.send_response(404)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'Not found\\n')
    
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'OK\\n')
        else:
            self.do_POST()

try:
    with socketserver.TCPServer(('0.0.0.0', $PORT), AlertWebhookHandler) as httpd:
        print(f'Alert webhook server listening on port $PORT')
        httpd.serve_forever()
except Exception as e:
    print(f'Error starting server: {e}')
    exit(1)
"
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
    networking.firewall.allowedTCPPorts = [ cfg.network.alertmanagerPort 9097 ];
  };
}