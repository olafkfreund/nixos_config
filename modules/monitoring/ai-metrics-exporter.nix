# AI Metrics Exporter Module
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.monitoring;
  aiCfg = config.monitoring.aiMetricsExporter;
in {
  options.monitoring.aiMetricsExporter = {
    enable = mkEnableOption "Enable AI metrics exporter for Prometheus";
    
    port = mkOption {
      type = types.int;
      default = 9105;
      description = "AI metrics exporter port";
    };
    
    interval = mkOption {
      type = types.str;
      default = "30s";
      description = "Metrics collection interval";
    };
    
    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/ai-analysis";
      description = "AI analysis data directory";
    };
  };

  config = mkIf (cfg.enable && cfg.features.aiMetrics && aiCfg.enable) {
    # AI Metrics Exporter Service
    systemd.services.ai-metrics-exporter = {
      description = "AI Metrics Exporter for Prometheus";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
        Restart = "always";
        RestartSec = "10s";
        
        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadOnlyPaths = [ aiCfg.dataDir ];
        ReadWritePaths = [ "/tmp" ];
        
        Environment = [
          "PATH=${lib.makeBinPath (with pkgs; [ 
            coreutils curl jq python3 gnugrep gnused
          ])}"
        ];
        
        ExecStart = pkgs.writeShellScript "ai-metrics-exporter" ''
          #!/bin/bash
          set -euo pipefail
          
          # Configuration
          EXPORTER_PORT="${toString aiCfg.port}"
          COLLECTION_INTERVAL="${aiCfg.interval}"
          AI_DATA_DIR="${aiCfg.dataDir}"
          METRICS_FILE="/tmp/ai-metrics.prom"
          
          # Logging
          log() {
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
          }
          
          # Convert JSON metrics to Prometheus format
          generate_ai_metrics() {
              log "Generating AI metrics from $AI_DATA_DIR..."
              
              cat > "$METRICS_FILE" << 'EOF'
# HELP ai_exporter_up AI metrics exporter status
# TYPE ai_exporter_up gauge
ai_exporter_up 1

# HELP ai_exporter_last_update Last update timestamp
# TYPE ai_exporter_last_update gauge
EOF
              echo "ai_exporter_last_update $(date +%s)" >> "$METRICS_FILE"
              echo "" >> "$METRICS_FILE"
              
              # Process performance metrics
              if [[ -f "$AI_DATA_DIR/performance-metrics.json" ]]; then
                  local perf_file="$AI_DATA_DIR/performance-metrics.json"
                  
                  cat >> "$METRICS_FILE" << 'EOF'
# HELP ai_system_cpu_usage_percent System CPU usage percentage
# TYPE ai_system_cpu_usage_percent gauge
# HELP ai_system_memory_usage_percent System memory usage percentage
# TYPE ai_system_memory_usage_percent gauge
# HELP ai_system_disk_usage_percent System disk usage percentage
# TYPE ai_system_disk_usage_percent gauge
# HELP ai_system_load_average_1m System 1-minute load average
# TYPE ai_system_load_average_1m gauge
# HELP ai_services_running Number of AI services running
# TYPE ai_services_running gauge
EOF
                  
                  # Clean JSON file first to handle invalid characters
                  local clean_perf_file="/tmp/perf-metrics-clean.json"
                  # Remove control characters and fix newlines in JSON strings
                  cat "$perf_file" | tr -d '\000-\037' | sed 's/\n/ /g' > "$clean_perf_file" 2>/dev/null || cp "$perf_file" "$clean_perf_file"
                  
                  # Extract metrics using jq from cleaned file
                  local hostname=$(jq -r '.hostname // "unknown"' "$clean_perf_file" 2>/dev/null || echo "unknown")
                  local cpu_usage=$(jq -r '.system_metrics.cpu_usage_percent // "0"' "$clean_perf_file" 2>/dev/null || echo "0")
                  local memory_usage=$(jq -r '.system_metrics.memory_usage_percent // "0"' "$clean_perf_file" 2>/dev/null || echo "0")
                  local disk_usage=$(jq -r '.system_metrics.disk_usage_percent // "0"' "$clean_perf_file" 2>/dev/null || echo "0")
                  local load_avg=$(jq -r '.system_metrics.load_average_1m // "0"' "$clean_perf_file" 2>/dev/null || echo "0")
                  local ai_services=$(jq -r '.ai_metrics.ai_services_running // "0"' "$clean_perf_file" 2>/dev/null || echo "0")
                  
                  # Clean numeric values
                  cpu_usage=$(echo "$cpu_usage" | sed 's/[^0-9.]//g' | head -c 10)
                  memory_usage=$(echo "$memory_usage" | sed 's/[^0-9.]//g' | head -c 10)
                  disk_usage=$(echo "$disk_usage" | sed 's/[^0-9.]//g' | head -c 10)
                  load_avg=$(echo "$load_avg" | sed 's/[^0-9.]//g' | head -c 10)
                  ai_services=$(echo "$ai_services" | sed 's/[^0-9]//g' | head -c 10)
                  
                  # Validate and default values
                  [[ -z "$cpu_usage" || ! "$cpu_usage" =~ ^[0-9.]+$ ]] && cpu_usage=0
                  [[ -z "$memory_usage" || ! "$memory_usage" =~ ^[0-9.]+$ ]] && memory_usage=0
                  [[ -z "$disk_usage" || ! "$disk_usage" =~ ^[0-9.]+$ ]] && disk_usage=0
                  [[ -z "$load_avg" || ! "$load_avg" =~ ^[0-9.]+$ ]] && load_avg=0
                  [[ -z "$ai_services" || ! "$ai_services" =~ ^[0-9]+$ ]] && ai_services=0
                  
                  cat >> "$METRICS_FILE" << EOF
ai_system_cpu_usage_percent{hostname="$hostname"} $cpu_usage
ai_system_memory_usage_percent{hostname="$hostname"} $memory_usage
ai_system_disk_usage_percent{hostname="$hostname"} $disk_usage
ai_system_load_average_1m{hostname="$hostname"} $load_avg
ai_services_running{hostname="$hostname"} $ai_services

EOF
              fi
              
              # Process remediation report
              if [[ -f "$AI_DATA_DIR/remediation-report.json" ]]; then
                  local remediation_file="$AI_DATA_DIR/remediation-report.json"
                  
                  cat >> "$METRICS_FILE" << 'EOF'
# HELP ai_remediation_safe_mode AI remediation safe mode status
# TYPE ai_remediation_safe_mode gauge
# HELP ai_remediation_self_healing AI remediation self healing status
# TYPE ai_remediation_self_healing gauge
# HELP ai_remediation_actions_disk_cleanup AI remediation disk cleanup enabled
# TYPE ai_remediation_actions_disk_cleanup gauge
# HELP ai_remediation_actions_memory_optimization AI remediation memory optimization enabled
# TYPE ai_remediation_actions_memory_optimization gauge
EOF
                  
                  local hostname=$(jq -r '.hostname // "unknown"' "$remediation_file" 2>/dev/null || echo "unknown")
                  local safe_mode=$(jq -r '.safe_mode // false' "$remediation_file" 2>/dev/null)
                  local self_healing=$(jq -r '.self_healing // false' "$remediation_file" 2>/dev/null)
                  local disk_cleanup=$(jq -r '.actions_enabled.disk_cleanup // false' "$remediation_file" 2>/dev/null)
                  local memory_opt=$(jq -r '.actions_enabled.memory_optimization // false' "$remediation_file" 2>/dev/null)
                  
                  # Convert boolean to numeric
                  [[ "$safe_mode" == "true" ]] && safe_mode=1 || safe_mode=0
                  [[ "$self_healing" == "true" ]] && self_healing=1 || self_healing=0
                  [[ "$disk_cleanup" == "true" ]] && disk_cleanup=1 || disk_cleanup=0
                  [[ "$memory_opt" == "true" ]] && memory_opt=1 || memory_opt=0
                  
                  cat >> "$METRICS_FILE" << EOF
ai_remediation_safe_mode{hostname="$hostname"} $safe_mode
ai_remediation_self_healing{hostname="$hostname"} $self_healing
ai_remediation_actions_disk_cleanup{hostname="$hostname"} $disk_cleanup
ai_remediation_actions_memory_optimization{hostname="$hostname"} $memory_opt

EOF
              fi
              
              # Process memory optimization report
              if [[ -f "$AI_DATA_DIR/memory-optimization-report.json" ]]; then
                  local memory_file="$AI_DATA_DIR/memory-optimization-report.json"
                  
                  cat >> "$METRICS_FILE" << 'EOF'
# HELP ai_memory_optimization_status Memory optimization status
# TYPE ai_memory_optimization_status gauge
EOF
                  
                  local hostname=$(jq -r '.hostname // "unknown"' "$memory_file" 2>/dev/null || echo "unknown")
                  local status="completed"  # Default status since new format doesn't have status field
                  local status_value=1
                  
                  # Check if actions_taken exists as indicator of completion
                  local actions_taken=$(jq -r '.actions_taken // []' "$memory_file" 2>/dev/null)
                  if [[ "$actions_taken" == "[]" || "$actions_taken" == "null" ]]; then
                      status="no_actions"
                      status_value=0
                  fi
                  
                  cat >> "$METRICS_FILE" << EOF
ai_memory_optimization_status{hostname="$hostname",status="$status"} $status_value

EOF
              fi
              
              # Count AI analysis files for activity indicator
              local analysis_files=$(find "$AI_DATA_DIR" -name "*.json" -mtime -1 2>/dev/null | wc -l 2>/dev/null || echo "0")
              
              # Validate analysis_files is a number
              if ! [[ "$analysis_files" =~ ^[0-9]+$ ]]; then
                  analysis_files=0
              fi
              
              cat >> "$METRICS_FILE" << EOF
# HELP ai_analysis_files_recent Recent AI analysis files count
# TYPE ai_analysis_files_recent gauge
ai_analysis_files_recent $analysis_files

# HELP ai_last_metrics_update AI metrics last update timestamp
# TYPE ai_last_metrics_update gauge
ai_last_metrics_update $(date +%s)
EOF
              
              log "AI metrics generated with $(wc -l < "$METRICS_FILE" || echo "unknown") lines"
          }
          
          # HTTP server for metrics
          serve_metrics() {
              log "Starting AI metrics server on port $EXPORTER_PORT..."
              
              python3 -c "
import http.server
import socketserver
import socket

class AIMetricsHandler(http.server.SimpleHTTPRequestHandler):
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
                self.wfile.write(f'# Error reading AI metrics: {str(e)}\\n'.encode('utf-8'))
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

class ReusableTCPServer(socketserver.TCPServer):
    def server_bind(self):
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        super().server_bind()

print('Starting AI metrics HTTP server on port $EXPORTER_PORT')
with ReusableTCPServer(('0.0.0.0', $EXPORTER_PORT), AIMetricsHandler) as httpd:
    httpd.serve_forever()
" &
              HTTP_PID=$!
              
              # Main metrics collection loop
              while true; do
                  generate_ai_metrics
                  
                  # Convert interval to seconds
                  sleep_seconds=$(echo "${aiCfg.interval}" | sed 's/s$//' | sed 's/m$/*60/' | bc 2>/dev/null || echo "30")
                  sleep "$sleep_seconds"
              done
          }
          
          # Initialize
          echo "# AI metrics starting..." > "$METRICS_FILE"
          
          # Start metrics server and collection
          serve_metrics
        '';
      };
    };
    
    # Create user and group
    users.users.ai-metrics-exporter = {
      isSystemUser = true;
      group = "ai-metrics-exporter";
      description = "AI Metrics Exporter service user";
    };
    
    users.groups.ai-metrics-exporter = {};
    
    # Required packages
    environment.systemPackages = with pkgs; [
      curl
      jq
      bc
      python3
    ];
    
    # Open firewall port
    networking.firewall.allowedTCPPorts = [ aiCfg.port ];
  };
}