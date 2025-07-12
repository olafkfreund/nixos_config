# Plex/Tautulli Prometheus Exporter Module
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.monitoring.plexExporter;
in {
  options.monitoring.plexExporter = {
    enable = mkEnableOption "Enable Plex/Tautulli Prometheus exporter";
    
    tautulliUrl = mkOption {
      type = types.str;
      default = "http://localhost:8181";
      description = "Tautulli API URL";
    };
    
    apiKey = mkOption {
      type = types.str;
      default = "";
      description = "Tautulli API key";
    };
    
    port = mkOption {
      type = types.int;
      default = 9104;
      description = "Exporter port";
    };
    
    interval = mkOption {
      type = types.str;
      default = "60s";
      description = "Metrics collection interval";
    };
    
    historyDays = mkOption {
      type = types.int;
      default = 30;
      description = "Days of history to analyze";
    };
  };

  config = mkIf cfg.enable {
    # Plex/Tautulli Prometheus Exporter Service
    systemd.services.plex-exporter = {
      description = "Plex/Tautulli Prometheus Exporter";
      after = [ "network.target" "tautulli.service" ];
      wants = [ "tautulli.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "plex-exporter";
        Group = "plex-exporter";
        Restart = "always";
        RestartSec = "15s";
        Environment = [
          "PATH=${lib.makeBinPath (with pkgs; [ curl jq coreutils bc gnugrep gnused python3 gawk ])}"
        ];
        
        ExecStart = pkgs.writeShellScript "plex-exporter" ''
          #!/bin/bash
          
          # Configuration
          TAUTULLI_URL="${cfg.tautulliUrl}"
          API_KEY="${cfg.apiKey}"
          EXPORTER_PORT="${toString cfg.port}"
          UPDATE_INTERVAL="${cfg.interval}"
          HISTORY_DAYS="${toString cfg.historyDays}"
          
          # Metrics file
          METRICS_FILE="/tmp/plex-metrics.prom"
          TEMP_DIR="/tmp/plex-exporter"
          mkdir -p "$TEMP_DIR"
          
          # Logging
          log() {
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
          }
          
          # Function to call Tautulli API
          tautulli_api() {
              local endpoint="$1"
              local params="$2"
              curl -s "$TAUTULLI_URL/api/v2?apikey=$API_KEY&cmd=$endpoint$params" \
                  --connect-timeout 15 --max-time 45 || echo '{"response": {"result": "error"}}'
          }
          
          # Function to extract JSON value safely
          json_value() {
              echo "$1" | jq -r "$2" 2>/dev/null | sed 's/null/0/g' || echo "0"
          }
          
          # Function to get current activity
          get_current_activity() {
              log "Getting current Plex activity..."
              local activity_data=$(tautulli_api "get_activity")
              
              # Parse current streams
              local stream_count=$(json_value "$activity_data" '.response.data.stream_count')
              local transcode_count=$(json_value "$activity_data" '.response.data.stream_count_transcode')
              local direct_count=$(json_value "$activity_data" '.response.data.stream_count_direct_play')
              local total_bandwidth=$(json_value "$activity_data" '.response.data.total_bandwidth')
              local wan_bandwidth=$(json_value "$activity_data" '.response.data.wan_bandwidth')
              local lan_bandwidth=$(json_value "$activity_data" '.response.data.lan_bandwidth')
              
              echo "plex_current_streams $stream_count"
              echo "plex_current_transcodes $transcode_count"
              echo "plex_current_direct_plays $direct_count"
              echo "plex_total_bandwidth_kbps $total_bandwidth"
              echo "plex_wan_bandwidth_kbps $wan_bandwidth"
              echo "plex_lan_bandwidth_kbps $lan_bandwidth"
              
              # Parse individual sessions for detailed metrics
              echo "$activity_data" | jq -r '.response.data.sessions[]? | 
                  "plex_session_bandwidth_kbps{user=\"" + (.username // "unknown") + "\",location=\"" + (.location // "unknown") + "\",player=\"" + (.player // "unknown") + "\"} " + (.bandwidth // "0")' >> "$TEMP_DIR/sessions.prom"
              
              echo "$activity_data" | jq -r '.response.data.sessions[]? | 
                  "plex_session_progress_percent{user=\"" + (.username // "unknown") + "\",title=\"" + (.full_title // "unknown") + "\"} " + (.progress_percent // "0")' >> "$TEMP_DIR/sessions.prom"
          }
          
          # Function to get server statistics
          get_server_stats() {
              log "Getting Plex server statistics..."
              local server_data=$(tautulli_api "get_server_info")
              
              # Parse server info
              local version=$(json_value "$server_data" '.response.data.version' | tr -d '"')
              local platform=$(json_value "$server_data" '.response.data.platform' | tr -d '"')
              
              echo "plex_server_info{version=\"$version\",platform=\"$platform\"} 1"
              
              # Get library statistics
              local libraries_data=$(tautulli_api "get_libraries")
              echo "$libraries_data" | jq -r '.response.data[]? | 
                  "plex_library_count{library=\"" + (.section_name // "unknown") + "\",type=\"" + (.section_type // "unknown") + "\"} " + (.count // "0")' >> "$TEMP_DIR/libraries.prom"
          }
          
          # Function to get top statistics
          get_top_stats() {
              log "Getting top statistics..."
              
              # Top movies (last 30 days)
              local top_movies=$(tautulli_api "get_home_stats" "&time_range=$HISTORY_DAYS&stats_type=top_movies&stats_count=10")
              echo "$top_movies" | jq -r '.response.data[]? | 
                  "plex_top_movies_plays{title=\"" + (.title // "unknown") + "\",year=\"" + (.year // "0") + "\"} " + (.total_plays // "0")' >> "$TEMP_DIR/top_content.prom"
              
              # Top TV shows
              local top_shows=$(tautulli_api "get_home_stats" "&time_range=$HISTORY_DAYS&stats_type=top_tv&stats_count=10")
              echo "$top_shows" | jq -r '.response.data[]? | 
                  "plex_top_shows_plays{title=\"" + (.title // "unknown") + "\",year=\"" + (.year // "0") + "\"} " + (.total_plays // "0")' >> "$TEMP_DIR/top_content.prom"
              
              # Top users
              local top_users=$(tautulli_api "get_home_stats" "&time_range=$HISTORY_DAYS&stats_type=top_users&stats_count=10")
              echo "$top_users" | jq -r '.response.data[]? | 
                  "plex_top_users_plays{user=\"" + (.friendly_name // "unknown") + "\"} " + (.total_plays // "0")' >> "$TEMP_DIR/top_users.prom"
              
              echo "$top_users" | jq -r '.response.data[]? | 
                  "plex_top_users_duration_hours{user=\"" + (.friendly_name // "unknown") + "\"} " + ((.total_duration // 0) / 3600 | floor | tostring)' >> "$TEMP_DIR/top_users.prom"
          }
          
          # Function to get geographic and platform stats
          get_geo_platform_stats() {
              log "Getting geographic and platform statistics..."
              
              # Get recent sessions for geographic analysis
              local recent_history=$(tautulli_api "get_history" "&length=100")
              
              # Extract country/location data
              echo "$recent_history" | jq -r '.response.data.data[]? | 
                  select(.location != null and .location != "") |
                  "plex_plays_by_location{location=\"" + (.location // "unknown") + "\",country=\"" + (.location // "unknown") + "\"} 1"' | 
                  sort | uniq -c | awk '{print $2 " " $1}' >> "$TEMP_DIR/geo_stats.prom"
              
              # Extract platform/player data
              echo "$recent_history" | jq -r '.response.data.data[]? | 
                  select(.player != null and .player != "") |
                  "plex_plays_by_platform{platform=\"" + (.platform // "unknown") + "\",player=\"" + (.player // "unknown") + "\"} 1"' | 
                  sort | uniq -c | awk '{print $2 " " $1}' >> "$TEMP_DIR/platform_stats.prom"
              
              # Extract IP-based statistics (anonymized)
              echo "$recent_history" | jq -r '.response.data.data[]? | 
                  select(.ip_address != null and .ip_address != "") |
                  "plex_unique_ips{ip_hash=\"" + (.ip_address | @base64) + "\"} 1"' | 
                  sort | uniq -c | awk '{print $2 " " $1}' >> "$TEMP_DIR/ip_stats.prom"
          }
          
          # Function to get watch time statistics
          get_watch_time_stats() {
              log "Getting watch time statistics..."
              
              # Daily watch time for last 30 days
              for i in $(seq 0 $HISTORY_DAYS); do
                  local date=$(date -d "$i days ago" +%Y-%m-%d)
                  local day_stats=$(tautulli_api "get_plays_by_date" "&time_range=1&start_date=$date")
                  local total_duration=$(echo "$day_stats" | jq -r '.response.data[]? | .total_duration // 0' | awk '{sum += $1} END {print sum || 0}')
                  local total_plays=$(echo "$day_stats" | jq -r '.response.data[]? | .total_plays // 0' | awk '{sum += $1} END {print sum || 0}')
                  
                  # Ensure values are never empty
                  [ -z "$total_duration" ] && total_duration=0
                  [ -z "$total_plays" ] && total_plays=0
                  
                  local watch_hours=$(echo "scale=2; $total_duration / 3600" | bc 2>/dev/null || echo "0")
                  [ -z "$watch_hours" ] && watch_hours=0
                  
                  echo "plex_daily_watch_hours{date=\"$date\"} $watch_hours" >> "$TEMP_DIR/daily_stats.prom"
                  echo "plex_daily_plays{date=\"$date\"} $total_plays" >> "$TEMP_DIR/daily_stats.prom"
              done
          }
          
          # Function to get quality statistics
          get_quality_stats() {
              log "Getting quality and transcode statistics..."
              
              # Get stream statistics
              local stream_stats=$(tautulli_api "get_stream_type_stats" "&time_range=$HISTORY_DAYS")
              echo "$stream_stats" | jq -r '.response.data[]? | 
                  "plex_stream_type_count{type=\"" + (.stream_type // "unknown") + "\"} " + (.total_plays // "0")' >> "$TEMP_DIR/quality_stats.prom"
              
              # Get resolution statistics  
              local resolution_stats=$(tautulli_api "get_plays_by_stream_resolution" "&time_range=$HISTORY_DAYS")
              echo "$resolution_stats" | jq -r '.response.data[]? | 
                  "plex_resolution_plays{resolution=\"" + (.stream_video_resolution // "unknown") + "\"} " + (.total_plays // "0")' >> "$TEMP_DIR/quality_stats.prom"
          }
          
          # Function to compile all metrics
          compile_metrics() {
              log "Compiling all metrics..."
              
              # Clear temporary files
              rm -f "$TEMP_DIR"/*.prom
              
              # Collect all metrics
              {
                  echo "# HELP plex_current_streams Current number of active streams"
                  echo "# TYPE plex_current_streams gauge"
                  
                  echo "# HELP plex_current_transcodes Current number of transcoding streams"
                  echo "# TYPE plex_current_transcodes gauge"
                  
                  echo "# HELP plex_current_direct_plays Current number of direct play streams"
                  echo "# TYPE plex_current_direct_plays gauge"
                  
                  echo "# HELP plex_total_bandwidth_kbps Total bandwidth usage in Kbps"
                  echo "# TYPE plex_total_bandwidth_kbps gauge"
                  
                  echo "# HELP plex_wan_bandwidth_kbps WAN bandwidth usage in Kbps"
                  echo "# TYPE plex_wan_bandwidth_kbps gauge"
                  
                  echo "# HELP plex_lan_bandwidth_kbps LAN bandwidth usage in Kbps"
                  echo "# TYPE plex_lan_bandwidth_kbps gauge"
                  
                  get_current_activity
                  get_server_stats
                  get_top_stats
                  get_geo_platform_stats
                  get_watch_time_stats
                  get_quality_stats
                  
                  # Include temporary metrics files
                  cat "$TEMP_DIR"/*.prom 2>/dev/null || true
                  
                  echo "# HELP plex_exporter_up Plex exporter availability"
                  echo "# TYPE plex_exporter_up gauge"
                  echo "plex_exporter_up 1"
                  
                  echo "# HELP plex_exporter_last_update Last successful update timestamp"
                  echo "# TYPE plex_exporter_last_update gauge"
                  echo "plex_exporter_last_update $(date +%s)"
                  
              } > "$METRICS_FILE"
              
              log "Metrics compilation completed. Metrics file size: $(wc -l < "$METRICS_FILE") lines"
          }
          
          # Function to serve metrics via HTTP
          serve_metrics() {
              log "Starting Plex metrics server on port $EXPORTER_PORT..."
              
              # Create Python HTTP server for metrics
              python3 -c "
import http.server
import socketserver
import os
import threading
import time

class PlexMetricsHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain; charset=utf-8')
            self.end_headers()
            try:
                with open('$METRICS_FILE', 'r') as f:
                    content = f.read()
                    self.wfile.write(content.encode('utf-8'))
            except Exception as e:
                self.wfile.write(f'# Error reading metrics: {str(e)}\n'.encode('utf-8'))
        elif self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'OK')
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        pass  # Suppress HTTP logs

print('Starting Plex exporter HTTP server on port $EXPORTER_PORT')
with socketserver.TCPServer(('0.0.0.0', $EXPORTER_PORT), PlexMetricsHandler) as httpd:
    httpd.serve_forever()
" &
              HTTP_PID=$!
              
              # Wait for server to be available
              sleep 5
              
              # Keep the server running and restart if it fails
              while true; do
                  if ! kill -0 $HTTP_PID 2>/dev/null; then
                      log "HTTP server died, restarting..."
                      python3 -c "
import http.server
import socketserver

class PlexMetricsHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain; charset=utf-8')
            self.end_headers()
            try:
                with open('$METRICS_FILE', 'r') as f:
                    content = f.read()
                    self.wfile.write(content.encode('utf-8'))
            except:
                self.wfile.write(b'# No metrics available\n')
        else:
            self.send_response(404)
            self.end_headers()
    def log_message(self, format, *args):
        pass

with socketserver.TCPServer(('0.0.0.0', $EXPORTER_PORT), PlexMetricsHandler) as httpd:
    httpd.serve_forever()
" &
                      HTTP_PID=$!
                  fi
                  sleep 60
              done
          }
          
          # Initialize metrics file
          echo "# Plex metrics initializing..." > "$METRICS_FILE"
          
          # Start metrics collection loop
          {
              while true; do
                  compile_metrics
                  sleep_seconds=$(echo "${cfg.interval}" | sed 's/s$//' | sed 's/m$/*60/' | bc 2>/dev/null || echo "60")
                  sleep "$sleep_seconds"
              done
          } &
          
          # Start HTTP server
          serve_metrics
        '';
      };
    };
    
    # Create user for the exporter
    users.users.plex-exporter = {
      isSystemUser = true;
      group = "plex-exporter";
      description = "Plex Exporter user";
    };
    
    users.groups.plex-exporter = {};
    
    # Required packages
    environment.systemPackages = with pkgs; [
      curl
      jq
      bc
      python3
    ];
  };
}