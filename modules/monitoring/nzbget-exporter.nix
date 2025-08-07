# NZBGet Prometheus Exporter Module
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.monitoring.nzbgetExporter;
in
{
  options.monitoring.nzbgetExporter = {
    enable = mkEnableOption "Enable NZBGet Prometheus exporter";

    nzbgetUrl = mkOption {
      type = types.str;
      default = "http://localhost:6789";
      description = "NZBGet API URL";
    };

    username = mkOption {
      type = types.str;
      default = "nzbget";
      description = "NZBGet username";
    };

    password = mkOption {
      type = types.str;
      default = "Xs4monly4e!!";
      description = "NZBGet password";
    };

    port = mkOption {
      type = types.int;
      default = 9103;
      description = "Exporter port";
    };

    interval = mkOption {
      type = types.str;
      default = "30s";
      description = "Metrics collection interval";
    };
  };

  config = mkIf cfg.enable {
    # NZBGet Prometheus Exporter Service
    systemd.services.nzbget-exporter = {
      description = "NZBGet Prometheus Exporter";
      after = [ "network.target" "nzbget.service" ];
      wants = [ "nzbget.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "nzbget-exporter";
        Group = "nzbget-exporter";
        Restart = "always";
        RestartSec = "10s";
        Environment = [
          "PATH=${lib.makeBinPath (with pkgs; [ curl jq coreutils bc gnugrep gnused netcat-gnu python3 ])}"
        ];

        ExecStart = pkgs.writeShellScript "nzbget-exporter" ''
                    #!/bin/bash
          
                    # NZBGet API configuration
                    NZBGET_URL="${cfg.nzbgetUrl}"
                    NZBGET_USER="${cfg.username}"
                    NZBGET_PASS="${cfg.password}"
                    EXPORTER_PORT="${toString cfg.port}"
                    UPDATE_INTERVAL="${cfg.interval}"
          
                    # Metrics file for serving
                    METRICS_FILE="/tmp/nzbget-metrics.prom"
          
                    # Logging
                    log() {
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
                    }
          
                    # Function to get NZBGet API data
                    get_nzbget_data() {
                        local endpoint="$1"
                        curl -s -u "$NZBGET_USER:$NZBGET_PASS" \
                            "$NZBGET_URL/jsonrpc/$endpoint" \
                            --connect-timeout 10 \
                            --max-time 30 || echo "{}"
                    }
          
                    # Function to extract JSON value
                    json_value() {
                        echo "$1" | jq -r "$2" 2>/dev/null || echo "0"
                    }
          
                    # Function to collect NZBGet metrics
                    collect_metrics() {
                        log "Collecting NZBGet metrics..."
              
                        # Get status data
                        local status_data=$(get_nzbget_data "status")
                        local history_data=$(get_nzbget_data "history")
                        local listgroups_data=$(get_nzbget_data "listgroups")
              
                        # Parse status metrics
                        local download_rate=$(json_value "$status_data" '.result.DownloadRate')
                        local remaining_size=$(json_value "$status_data" '.result.RemainingSizeMB')
                        local queue_size=$(json_value "$status_data" '.result.DownloadedSizeMB')
                        local uptime=$(json_value "$status_data" '.result.UpTimeSec')
                        local download_limit=$(json_value "$status_data" '.result.DownloadLimit')
                        local thread_count=$(json_value "$status_data" '.result.ThreadCount')
                        local server_standby=$(json_value "$status_data" '.result.ServerStandBy')
                        local post_paused=$(json_value "$status_data" '.result.PostPaused')
                        local download_paused=$(json_value "$status_data" '.result.DownloadPaused')
                        local quota_reached=$(json_value "$status_data" '.result.QuotaReached')
              
                        # Parse queue data
                        local queue_count=0
                        local queue_total_size=0
                        local queue_remaining_size=0
              
                        if [ "$listgroups_data" != "{}" ]; then
                            queue_count=$(echo "$listgroups_data" | jq -r '.result | length' 2>/dev/null || echo "0")
                            queue_total_size=$(echo "$listgroups_data" | jq -r '[.result[]? | .FileSizeMB] | add // 0' 2>/dev/null || echo "0")
                            queue_remaining_size=$(echo "$listgroups_data" | jq -r '[.result[]? | .RemainingSizeMB] | add // 0' 2>/dev/null || echo "0")
                        fi
              
                        # Ensure values are never null or empty
                        [ -z "$queue_count" ] || [ "$queue_count" = "null" ] && queue_count=0
                        [ -z "$queue_total_size" ] || [ "$queue_total_size" = "null" ] && queue_total_size=0
                        [ -z "$queue_remaining_size" ] || [ "$queue_remaining_size" = "null" ] && queue_remaining_size=0
              
                        # Parse history data
                        local completed_count=0
                        local failed_count=0
                        local total_downloaded=0
              
                        if [ "$history_data" != "{}" ]; then
                            completed_count=$(echo "$history_data" | jq -r '[.result[]? | select(.Status == "SUCCESS")] | length' 2>/dev/null || echo "0")
                            failed_count=$(echo "$history_data" | jq -r '[.result[]? | select(.Status != "SUCCESS")] | length' 2>/dev/null || echo "0")
                            total_downloaded=$(echo "$history_data" | jq -r '[.result[]? | .FileSizeMB] | add // 0' 2>/dev/null || echo "0")
                        fi
              
                        # Ensure values are never null or empty
                        [ -z "$completed_count" ] || [ "$completed_count" = "null" ] && completed_count=0
                        [ -z "$failed_count" ] || [ "$failed_count" = "null" ] && failed_count=0
                        [ -z "$total_downloaded" ] || [ "$total_downloaded" = "null" ] && total_downloaded=0
              
                        # Convert download rate from bytes to KB/s
                        local download_rate_kbs=$(echo "scale=2; $download_rate / 1024" | bc 2>/dev/null || echo "0")
              
                        # Generate Prometheus metrics
                        cat > "$METRICS_FILE" << EOF
          # HELP nzbget_download_rate_kbps Current download rate in KB/s
          # TYPE nzbget_download_rate_kbps gauge
          nzbget_download_rate_kbps $download_rate_kbs

          # HELP nzbget_remaining_size_mb Remaining download size in MB
          # TYPE nzbget_remaining_size_mb gauge
          nzbget_remaining_size_mb $remaining_size

          # HELP nzbget_downloaded_size_mb Total downloaded size in MB
          # TYPE nzbget_downloaded_size_mb gauge
          nzbget_downloaded_size_mb $queue_size

          # HELP nzbget_uptime_seconds NZBGet uptime in seconds
          # TYPE nzbget_uptime_seconds counter
          nzbget_uptime_seconds $uptime

          # HELP nzbget_download_limit_kbps Download speed limit in KB/s
          # TYPE nzbget_download_limit_kbps gauge
          nzbget_download_limit_kbps $download_limit

          # HELP nzbget_thread_count Number of download threads
          # TYPE nzbget_thread_count gauge
          nzbget_thread_count $thread_count

          # HELP nzbget_server_standby Server standby status (1=standby, 0=active)
          # TYPE nzbget_server_standby gauge
          nzbget_server_standby $([ "$server_standby" = "true" ] && echo "1" || echo "0")

          # HELP nzbget_post_paused Post-processing paused status (1=paused, 0=active)
          # TYPE nzbget_post_paused gauge
          nzbget_post_paused $([ "$post_paused" = "true" ] && echo "1" || echo "0")

          # HELP nzbget_download_paused Download paused status (1=paused, 0=active)
          # TYPE nzbget_download_paused gauge
          nzbget_download_paused $([ "$download_paused" = "true" ] && echo "1" || echo "0")

          # HELP nzbget_quota_reached Quota reached status (1=reached, 0=not reached)
          # TYPE nzbget_quota_reached gauge
          nzbget_quota_reached $([ "$quota_reached" = "true" ] && echo "1" || echo "0")

          # HELP nzbget_queue_count Number of items in download queue
          # TYPE nzbget_queue_count gauge
          nzbget_queue_count $queue_count

          # HELP nzbget_queue_total_size_mb Total size of queue in MB
          # TYPE nzbget_queue_total_size_mb gauge
          nzbget_queue_total_size_mb $queue_total_size

          # HELP nzbget_queue_remaining_size_mb Remaining size of queue in MB
          # TYPE nzbget_queue_remaining_size_mb gauge
          nzbget_queue_remaining_size_mb $queue_remaining_size

          # HELP nzbget_completed_count Total number of completed downloads
          # TYPE nzbget_completed_count counter
          nzbget_completed_count $completed_count

          # HELP nzbget_failed_count Total number of failed downloads
          # TYPE nzbget_failed_count counter
          nzbget_failed_count $failed_count

          # HELP nzbget_total_downloaded_mb Total data downloaded in MB
          # TYPE nzbget_total_downloaded_mb counter
          nzbget_total_downloaded_mb $total_downloaded

          # HELP nzbget_up NZBGet availability (1=up, 0=down)
          # TYPE nzbget_up gauge
          nzbget_up $([ "$download_rate" != "" ] && echo "1" || echo "0")

          EOF
              
                        log "Metrics updated: Queue=$queue_count, Rate=$(echo "scale=2; $download_rate / 1024" | bc 2>/dev/null || echo "0")KB/s, Completed=$completed_count, Failed=$failed_count"
                    }
          
                    # Function to serve metrics
                    serve_metrics() {
                        log "Starting metrics server on port $EXPORTER_PORT..."
              
                        # Use Python HTTP server for reliable metrics serving
                        python3 -c "
          import http.server
          import socketserver
          import socket
          import os

          class MetricsHandler(http.server.SimpleHTTPRequestHandler):
              def do_GET(self):
                  if self.path == '/metrics':
                      try:
                          self.send_response(200)
                          self.send_header('Content-type', 'text/plain; charset=utf-8')
                          self.end_headers()
                          try:
                              with open('$METRICS_FILE', 'r') as f:
                                  self.wfile.write(f.read().encode('utf-8'))
                          except:
                              self.wfile.write(b'# No metrics available\\n')
                      except BrokenPipeError:
                          # Client disconnected - ignore
                          pass
                  elif self.path == '/health':
                      try:
                          self.send_response(200)
                          self.send_header('Content-type', 'text/plain')
                          self.end_headers()
                          self.wfile.write(b'OK\\n')
                      except BrokenPipeError:
                          # Client disconnected - ignore
                          pass
                  else:
                      try:
                          self.send_response(404)
                          self.end_headers()
                      except BrokenPipeError:
                          # Client disconnected - ignore
                          pass
    
              def log_message(self, format, *args):
                  # Disable default logging to avoid spam
                  pass

          class ReusableTCPServer(socketserver.TCPServer):
              def server_bind(self):
                  self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                  super().server_bind()

          print('Starting NZBGet exporter HTTP server on port $EXPORTER_PORT')
          with ReusableTCPServer(('0.0.0.0', $EXPORTER_PORT), MetricsHandler) as httpd:
              httpd.serve_forever()
          "
                    }
          
                    # Initialize metrics file
                    echo "# NZBGet metrics not available" > "$METRICS_FILE"
          
                    # Start metrics collection loop
                    {
                        while true; do
                            collect_metrics
                            sleep_seconds=$(echo "${cfg.interval}" | sed 's/s$//' | sed 's/m$/*60/' | bc 2>/dev/null || echo "30")
                            sleep "$sleep_seconds"
                        done
                    } &
          
                    # Start metrics server
                    serve_metrics
        '';
      };
    };

    # Create user for the exporter
    users.users.nzbget-exporter = {
      isSystemUser = true;
      group = "nzbget-exporter";
      description = "NZBGet Exporter user";
    };

    users.groups.nzbget-exporter = { };

    # Required packages
    environment.systemPackages = with pkgs; [
      curl
      jq
      bc
      netcat-gnu
      python3
    ];
  };
}
