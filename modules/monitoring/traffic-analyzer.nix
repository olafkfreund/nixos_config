# Traffic Analysis and Protocol Detection Module
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.monitoring;
  trafficCfg = config.monitoring.trafficAnalyzer;
in {
  options.monitoring.trafficAnalyzer = {
    enable = mkEnableOption "Enable network traffic analysis and protocol detection";
    
    interface = mkOption {
      type = types.str;
      default = "eno1";
      description = "Network interface for traffic capture";
    };
    
    port = mkOption {
      type = types.int;
      default = 9201;
      description = "Traffic analyzer metrics port";
    };
    
    captureInterval = mkOption {
      type = types.str;
      default = "30s";
      description = "Traffic capture and analysis interval";
    };
    
    enableDeepInspection = mkOption {
      type = types.bool;
      default = true;
      description = "Enable deep packet inspection for application detection";
    };
    
    enableGeoLocation = mkOption {
      type = types.bool;
      default = true;
      description = "Enable geographic analysis of external connections";
    };
    
    retentionDays = mkOption {
      type = types.int;
      default = 7;
      description = "Days to retain detailed traffic logs";
    };
  };

  config = mkIf (cfg.enable && cfg.features.trafficAnalysis) {
    # Traffic Analysis Service
    systemd.services.traffic-analyzer = {
      description = "Network Traffic Analysis and Protocol Detection Service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "traffic-analyzer";
        Group = "traffic-analyzer";
        Restart = "always";
        RestartSec = "15s";
        
        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ "/var/lib/traffic-analyzer" "/tmp" ];
        
        # Network capabilities for packet capture
        CapabilityBoundingSet = [ "CAP_NET_RAW" "CAP_NET_ADMIN" ];
        AmbientCapabilities = [ "CAP_NET_RAW" "CAP_NET_ADMIN" ];
        
        Environment = [
          "PATH=${lib.makeBinPath (with pkgs; [ 
            coreutils curl jq bc tcpdump netstat ss lsof
            python3 gnugrep gnused gawk iproute2 procps
          ])}"
        ];
        
        ExecStart = pkgs.writeShellScript "traffic-analyzer" ''
          #!/bin/bash
          set -euo pipefail
          
          # Configuration
          INTERFACE="${trafficCfg.interface}"
          EXPORTER_PORT="${toString trafficCfg.port}"
          CAPTURE_INTERVAL="${trafficCfg.captureInterval}"
          ENABLE_DPI="${if trafficCfg.enableDeepInspection then "true" else "false"}"
          ENABLE_GEO="${if trafficCfg.enableGeoLocation then "true" else "false"}"
          RETENTION_DAYS="${toString trafficCfg.retentionDays}"
          
          # Data directories
          DATA_DIR="/var/lib/traffic-analyzer"
          METRICS_FILE="/tmp/traffic-analyzer-metrics.prom"
          TRAFFIC_DB="$DATA_DIR/traffic.json"
          FLOWS_DB="$DATA_DIR/flows.json"
          GEO_DB="$DATA_DIR/geoip.json"
          
          # Traffic capture files
          CAPTURE_DIR="$DATA_DIR/captures"
          mkdir -p "$CAPTURE_DIR"
          
          # Logging
          log() {
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
          }
          
          # Initialize GeoIP database
          init_geoip_db() {
              if [[ "$ENABLE_GEO" == "true" && ! -f "$GEO_DB" ]]; then
                  log "Initializing GeoIP database..."
                  # Create a basic GeoIP lookup structure
                  echo '{"last_update": 0, "entries": {}}' > "$GEO_DB"
              fi
          }
          
          # Get geographic location for IP
          get_geo_location() {
              local ip="$1"
              if [[ "$ENABLE_GEO" == "true" ]]; then
                  # Use a free GeoIP service (rate limited)
                  local geo_info=$(curl -s --connect-timeout 2 --max-time 5 "http://ip-api.com/json/$ip?fields=country,regionName,city,isp" 2>/dev/null || echo '{"country":"Unknown"}')
                  echo "$geo_info"
              else
                  echo '{"country":"Unknown"}'
              fi
          }
          
          # Analyze network connections
          analyze_connections() {
              log "Analyzing active network connections..."
              
              # Get active connections using ss (modern netstat)
              local connections=$(ss -tuln 2>/dev/null || netstat -tuln 2>/dev/null || echo "")
              
              # Get process network usage
              local netstat_processes=""
              if command -v ss >/dev/null 2>&1; then
                  netstat_processes=$(ss -tulnp 2>/dev/null || echo "")
              fi
              
              # Get interface statistics
              local interface_stats=""
              if [[ -f "/proc/net/dev" ]]; then
                  interface_stats=$(grep "$INTERFACE" /proc/net/dev || echo "")
              fi
              
              # Parse interface statistics
              local rx_bytes=0 tx_bytes=0 rx_packets=0 tx_packets=0
              if [[ -n "$interface_stats" ]]; then
                  # Extract statistics from /proc/net/dev
                  read -r iface rx_bytes rx_packets rx_errs rx_drop rx_fifo rx_frame rx_compressed rx_multicast tx_bytes tx_packets tx_errs tx_drop tx_fifo tx_colls tx_carrier tx_compressed <<< $(echo "$interface_stats" | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17}')
              fi
              
              # Store current traffic counters
              local current_time=$(date +%s)
              local traffic_sample="{
                  \"timestamp\": $current_time,
                  \"interface\": \"$INTERFACE\",
                  \"rx_bytes\": $rx_bytes,
                  \"tx_bytes\": $tx_bytes,
                  \"rx_packets\": $rx_packets,
                  \"tx_packets\": $tx_packets
              }"
              
              # Load previous sample for rate calculation
              local traffic_history="[]"
              if [[ -f "$TRAFFIC_DB" ]]; then
                  traffic_history=$(cat "$TRAFFIC_DB")
              fi
              
              # Add current sample
              traffic_history=$(echo "$traffic_history" | jq --argjson sample "$traffic_sample" '. + [$sample]')
              
              # Keep only last 100 samples
              traffic_history=$(echo "$traffic_history" | jq 'if length > 100 then .[-100:] else . end')
              
              # Save traffic history
              echo "$traffic_history" > "$TRAFFIC_DB"
              
              log "Traffic analysis completed. RX: $rx_bytes bytes, TX: $tx_bytes bytes"
          }
          
          # Capture and analyze traffic flows
          analyze_traffic_flows() {
              if [[ "$ENABLE_DPI" != "true" ]]; then
                  return
              fi
              
              log "Capturing and analyzing traffic flows..."
              
              # Capture traffic for analysis (short duration)
              local capture_file="$CAPTURE_DIR/capture_$(date +%s).pcap"
              
              # Use tcpdump to capture traffic (5 second window)
              timeout 5 tcpdump -i "$INTERFACE" -c 1000 -w "$capture_file" 2>/dev/null || true
              
              if [[ -f "$capture_file" ]]; then
                  # Analyze captured traffic
                  local flow_analysis=$(tcpdump -r "$capture_file" -nn 2>/dev/null | head -100 | awk '
                  BEGIN { 
                      protocols["TCP"] = 0; protocols["UDP"] = 0; protocols["ICMP"] = 0; protocols["Other"] = 0;
                      ports[80] = "HTTP"; ports[443] = "HTTPS"; ports[22] = "SSH"; ports[53] = "DNS";
                      ports[25] = "SMTP"; ports[110] = "POP3"; ports[143] = "IMAP"; ports[993] = "IMAPS";
                      ports[995] = "POP3S"; ports[21] = "FTP"; ports[23] = "Telnet"; ports[3389] = "RDP";
                  }
                  /IP/ {
                      if ($0 ~ /TCP/) { protocols["TCP"]++; }
                      else if ($0 ~ /UDP/) { protocols["UDP"]++; }
                      else if ($0 ~ /ICMP/) { protocols["ICMP"]++; }
                      else { protocols["Other"]++; }
                      
                      # Extract port numbers
                      if (match($0, /\.([0-9]+) >/, port_match)) {
                          port = substr($0, RSTART+1, RLENGTH-3);
                          if (port in ports) {
                              services[ports[port]]++;
                          }
                      }
                  }
                  END {
                      printf "{\"protocols\":{";
                      first = 1;
                      for (p in protocols) {
                          if (!first) printf ",";
                          printf "\"%s\":%d", p, protocols[p];
                          first = 0;
                      }
                      printf "},\"services\":{";
                      first = 1;
                      for (s in services) {
                          if (!first) printf ",";
                          printf "\"%s\":%d", s, services[s];
                          first = 0;
                      }
                      printf "}}";
                  }' || echo '{"protocols":{},"services":{}}')
                  
                  # Store flow analysis
                  local timestamp=$(date +%s)
                  local flows=$(jq -n --arg ts "$timestamp" --argjson analysis "$flow_analysis" '{
                      "timestamp": ($ts | tonumber),
                      "analysis": $analysis
                  }')
                  
                  # Load flow history
                  local flow_history="[]"
                  if [[ -f "$FLOWS_DB" ]]; then
                      flow_history=$(cat "$FLOWS_DB")
                  fi
                  
                  # Add current analysis
                  flow_history=$(echo "$flow_history" | jq --argjson flows "$flows" '. + [$flows]')
                  
                  # Keep only last 50 flow analyses
                  flow_history=$(echo "$flow_history" | jq 'if length > 50 then .[-50:] else . end')
                  
                  # Save flow history
                  echo "$flow_history" > "$FLOWS_DB"
                  
                  # Clean up capture file
                  rm -f "$capture_file"
                  
                  log "Traffic flow analysis completed"
              fi
          }
          
          # Analyze top connections and bandwidth usage
          analyze_top_talkers() {
              log "Analyzing top bandwidth consumers..."
              
              # Get connection information with process details
              local connections=""
              if command -v ss >/dev/null 2>&1; then
                  connections=$(ss -tuln -p 2>/dev/null | grep -v "State" || echo "")
              fi
              
              # Get network interface statistics per connection (simplified)
              local top_connections="[]"
              
              # For each active connection, try to determine bandwidth usage
              while IFS= read -r line; do
                  if [[ -n "$line" && "$line" != *"State"* ]]; then
                      # Parse connection information
                      local proto=$(echo "$line" | awk '{print $1}')
                      local local_addr=$(echo "$line" | awk '{print $4}')
                      local remote_addr=$(echo "$line" | awk '{print $5}')
                      
                      # Extract IPs and ports
                      local local_ip=$(echo "$local_addr" | cut -d: -f1 | sed 's/\[//g' | sed 's/\]//g')
                      local local_port=$(echo "$local_addr" | awk -F: '{print $NF}')
                      local remote_ip=$(echo "$remote_addr" | cut -d: -f1 | sed 's/\[//g' | sed 's/\]//g')
                      local remote_port=$(echo "$remote_addr" | awk -F: '{print $NF}')
                      
                      # Skip local and empty connections
                      if [[ "$remote_ip" != "127.0.0.1" && "$remote_ip" != "0.0.0.0" && "$remote_ip" != "*" && -n "$remote_ip" ]]; then
                          # Get geographic info for external IPs
                          local geo_info='{"country":"Internal"}'
                          if [[ ! "$remote_ip" =~ ^192\.168\. && ! "$remote_ip" =~ ^10\. && ! "$remote_ip" =~ ^172\.(1[6-9]|2[0-9]|3[01])\. ]]; then
                              geo_info=$(get_geo_location "$remote_ip")
                          fi
                          
                          # Create connection record
                          local connection=$(jq -n \
                              --arg proto "$proto" \
                              --arg local_ip "$local_ip" \
                              --arg local_port "$local_port" \
                              --arg remote_ip "$remote_ip" \
                              --arg remote_port "$remote_port" \
                              --argjson geo "$geo_info" \
                              '{
                                  "protocol": $proto,
                                  "local_ip": $local_ip,
                                  "local_port": $local_port,
                                  "remote_ip": $remote_ip,
                                  "remote_port": $remote_port,
                                  "geo": $geo,
                                  "timestamp": now
                              }')
                          
                          top_connections=$(echo "$top_connections" | jq --argjson conn "$connection" '. + [$conn]')
                      fi
                  fi
              done <<< "$connections"
              
              # Save top connections
              echo "$top_connections" > "$DATA_DIR/top_connections.json"
              
              log "Top talkers analysis completed with $(echo "$top_connections" | jq 'length') connections"
          }
          
          # Generate comprehensive metrics
          generate_metrics() {
              log "Generating traffic analysis metrics..."
              
              cat > "$METRICS_FILE" << EOF
# HELP network_traffic_bytes_total Total network traffic in bytes
# TYPE network_traffic_bytes_total counter
EOF
              
              # Get current traffic statistics
              if [[ -f "$TRAFFIC_DB" ]]; then
                  local latest_sample=$(cat "$TRAFFIC_DB" | jq '.[-1]')
                  local rx_bytes=$(echo "$latest_sample" | jq -r '.rx_bytes // 0')
                  local tx_bytes=$(echo "$latest_sample" | jq -r '.tx_bytes // 0')
                  local rx_packets=$(echo "$latest_sample" | jq -r '.rx_packets // 0')
                  local tx_packets=$(echo "$latest_sample" | jq -r '.tx_packets // 0')
                  
                  cat >> "$METRICS_FILE" << EOF
network_traffic_bytes_total{direction="rx",interface="$INTERFACE"} $rx_bytes
network_traffic_bytes_total{direction="tx",interface="$INTERFACE"} $tx_bytes

# HELP network_traffic_packets_total Total network packets
# TYPE network_traffic_packets_total counter
network_traffic_packets_total{direction="rx",interface="$INTERFACE"} $rx_packets
network_traffic_packets_total{direction="tx",interface="$INTERFACE"} $tx_packets

EOF
                  
                  # Calculate traffic rates if we have previous sample
                  local samples_count=$(cat "$TRAFFIC_DB" | jq 'length')
                  if [[ "$samples_count" -gt 1 ]]; then
                      local prev_sample=$(cat "$TRAFFIC_DB" | jq '.[-2]')
                      local prev_rx=$(echo "$prev_sample" | jq -r '.rx_bytes // 0')
                      local prev_tx=$(echo "$prev_sample" | jq -r '.tx_bytes // 0')
                      local prev_time=$(echo "$prev_sample" | jq -r '.timestamp // 0')
                      local curr_time=$(echo "$latest_sample" | jq -r '.timestamp // 0')
                      
                      local time_diff=$((curr_time - prev_time))
                      if [[ "$time_diff" -gt 0 ]]; then
                          local rx_rate=$(((rx_bytes - prev_rx) / time_diff))
                          local tx_rate=$(((tx_bytes - prev_tx) / time_diff))
                          
                          cat >> "$METRICS_FILE" << EOF
# HELP network_traffic_rate_bytes_per_second Current traffic rate in bytes per second
# TYPE network_traffic_rate_bytes_per_second gauge
network_traffic_rate_bytes_per_second{direction="rx",interface="$INTERFACE"} $rx_rate
network_traffic_rate_bytes_per_second{direction="tx",interface="$INTERFACE"} $tx_rate

EOF
                      fi
                  fi
              fi
              
              # Protocol distribution metrics
              if [[ -f "$FLOWS_DB" ]]; then
                  local latest_flow=$(cat "$FLOWS_DB" | jq '.[-1].analysis // {}')
                  
                  cat >> "$METRICS_FILE" << EOF
# HELP network_protocol_packets Protocol distribution
# TYPE network_protocol_packets gauge
EOF
                  
                  echo "$latest_flow" | jq -r '.protocols // {} | to_entries[] | 
                      "network_protocol_packets{protocol=\"" + (.key | ascii_downcase) + "\"} " + (.value | tostring)' >> "$METRICS_FILE"
                  
                  cat >> "$METRICS_FILE" << EOF

# HELP network_service_connections Service connections
# TYPE network_service_connections gauge
EOF
                  
                  echo "$latest_flow" | jq -r '.services // {} | to_entries[] | 
                      "network_service_connections{service=\"" + (.key | ascii_downcase) + "\"} " + (.value | tostring)' >> "$METRICS_FILE"
              fi
              
              # Active connections metrics
              if [[ -f "$DATA_DIR/top_connections.json" ]]; then
                  local total_connections=$(cat "$DATA_DIR/top_connections.json" | jq 'length')
                  local external_connections=$(cat "$DATA_DIR/top_connections.json" | jq '[.[] | select(.geo.country != "Internal")] | length')
                  
                  cat >> "$METRICS_FILE" << EOF

# HELP network_active_connections Total active connections
# TYPE network_active_connections gauge
network_active_connections{type="total"} $total_connections
network_active_connections{type="external"} $external_connections

# HELP network_connections_by_country Connections by country
# TYPE network_connections_by_country gauge
EOF
                  
                  cat "$DATA_DIR/top_connections.json" | jq -r 'group_by(.geo.country) | .[] | 
                      "network_connections_by_country{country=\"" + .[0].geo.country + "\"} " + (length | tostring)' >> "$METRICS_FILE"
              fi
              
              cat >> "$METRICS_FILE" << EOF

# HELP network_traffic_analyzer_up Traffic analyzer status
# TYPE network_traffic_analyzer_up gauge
network_traffic_analyzer_up 1

# HELP network_traffic_analyzer_last_update Last update timestamp
# TYPE network_traffic_analyzer_last_update gauge
network_traffic_analyzer_last_update $(date +%s)
EOF
              
              log "Traffic analysis metrics generated"
          }
          
          # HTTP server for metrics
          serve_metrics() {
              log "Starting traffic analyzer metrics server on port $EXPORTER_PORT..."
              
              python3 -c "
import http.server
import socketserver
import json
import os

class TrafficAnalyzerHandler(http.server.SimpleHTTPRequestHandler):
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
        elif self.path == '/traffic':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            try:
                with open('$TRAFFIC_DB', 'r') as f:
                    content = f.read()
                    self.wfile.write(content.encode('utf-8'))
            except:
                self.wfile.write(b'[]')
        elif self.path == '/flows':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            try:
                with open('$FLOWS_DB', 'r') as f:
                    content = f.read()
                    self.wfile.write(content.encode('utf-8'))
            except:
                self.wfile.write(b'[]')
        elif self.path == '/connections':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            try:
                with open('$DATA_DIR/top_connections.json', 'r') as f:
                    content = f.read()
                    self.wfile.write(content.encode('utf-8'))
            except:
                self.wfile.write(b'[]')
        elif self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'OK')
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        pass

print('Starting traffic analyzer HTTP server on port $EXPORTER_PORT')
with socketserver.TCPServer(('0.0.0.0', $EXPORTER_PORT), TrafficAnalyzerHandler) as httpd:
    httpd.serve_forever()
" &
              HTTP_PID=$!
              
              # Main analysis loop
              while true; do
                  analyze_connections
                  analyze_traffic_flows
                  analyze_top_talkers
                  generate_metrics
                  
                  # Convert interval to seconds
                  sleep_seconds=$(echo "${trafficCfg.captureInterval}" | sed 's/s$//' | sed 's/m$/*60/' | bc 2>/dev/null || echo "30")
                  sleep "$sleep_seconds"
              done
          }
          
          # Cleanup old files
          cleanup_old_files() {
              find "$CAPTURE_DIR" -name "*.pcap" -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true
          }
          
          # Initialize
          mkdir -p "$DATA_DIR" "$CAPTURE_DIR"
          init_geoip_db
          echo "[]" > "$TRAFFIC_DB"
          echo "[]" > "$FLOWS_DB"
          echo "# Traffic analyzer starting..." > "$METRICS_FILE"
          
          # Start cleanup timer
          (
              while true; do
                  sleep 3600  # Run cleanup every hour
                  cleanup_old_files
              done
          ) &
          
          # Start metrics server and analysis
          serve_metrics
        '';
      };
    };
    
    # Create user and group
    users.users.traffic-analyzer = {
      isSystemUser = true;
      group = "traffic-analyzer";
      description = "Traffic Analyzer service user";
    };
    
    users.groups.traffic-analyzer = {};
    
    # Create data directory
    systemd.tmpfiles.rules = [
      "d /var/lib/traffic-analyzer 0755 traffic-analyzer traffic-analyzer -"
      "d /var/lib/traffic-analyzer/captures 0755 traffic-analyzer traffic-analyzer -"
    ];
    
    # Required packages
    environment.systemPackages = with pkgs; [
      tcpdump
      nettools  # includes netstat
      iproute2  # includes ss
      lsof
      procps
      curl
      jq
      bc
      python3
      gawk
    ];
    
    # Open firewall port
    networking.firewall.allowedTCPPorts = [ trafficCfg.port ];
  };
}