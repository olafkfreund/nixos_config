{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.ai.analysis;
  
  # Historical trend analysis script
  trendAnalysisScript = pkgs.writeShellScriptBin "ai-trend-analysis" ''
    set -euo pipefail
    
    export PATH="${lib.makeBinPath (with pkgs; [ curl jq coreutils util-linux bc python3 ])}"
    export AI_PROVIDER="''${AI_PROVIDER:-openai}"
    export OUTPUT_PATH="''${OUTPUT_PATH:-/var/lib/ai-analysis}"
    export LOG_FILE="/var/log/ai-analysis/predictive.log"
    
    # Load API keys from encrypted files
    if [ -r "/run/agenix/api-anthropic" ]; then
      export ANTHROPIC_API_KEY="$(cat /run/agenix/api-anthropic)"
    fi
    if [ -r "/run/agenix/api-openai" ]; then
      export OPENAI_API_KEY="$(cat /run/agenix/api-openai)"
    fi
    if [ -r "/run/agenix/api-gemini" ]; then
      export GEMINI_API_KEY="$(cat /run/agenix/api-gemini)"
    fi
    
    # Logging function
    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
    }
    
    # AI query function
    ai_query() {
        local prompt="$1"
        if [ -x "/run/current-system/sw/bin/ai-cli" ]; then
            /run/current-system/sw/bin/ai-cli -p "$AI_PROVIDER" "$prompt" 2>/dev/null || {
                log "AI query failed with provider $AI_PROVIDER"
                return 1
            }
        else
            log "ERROR: ai-cli not available at /run/current-system/sw/bin/ai-cli"
            return 1
        fi
    }
    
    # Prometheus range query function
    prometheus_range_query() {
        local query="$1"
        local duration="''${2:-24h}"
        local step="''${3:-300}"
        local monitoring_url="''${MONITORING_URL:-http://dex5550:9090}"
        
        curl -s -G "$monitoring_url/api/v1/query_range" \
            --data-urlencode "query=$query" \
            --data-urlencode "start=$(date -d "$duration ago" +%s)" \
            --data-urlencode "end=$(date +%s)" \
            --data-urlencode "step=$step" | jq -r '.data.result[0].values[]' 2>/dev/null || echo "[]"
    }
    
    # Statistical analysis function
    calculate_stats() {
        local data="$1"
        python3 -c "
import sys
import json
from statistics import mean, stdev, median

# Read data from stdin
data = []
for line in sys.stdin:
    if line.strip():
        try:
            timestamp, value = line.strip().split()
            data.append(float(value))
        except:
            continue

if len(data) < 2:
    print(json.dumps({'mean': 0, 'stdev': 0, 'median': 0, 'min': 0, 'max': 0, 'trend': 'stable', 'samples': 0}))
    sys.exit(0)

# Calculate statistics
stats = {
    'mean': round(mean(data), 2),
    'stdev': round(stdev(data), 2) if len(data) > 1 else 0,
    'median': round(median(data), 2),
    'min': round(min(data), 2),
    'max': round(max(data), 2),
    'samples': len(data)
}

# Simple trend analysis
if len(data) >= 10:
    first_half = data[:len(data)//2]
    second_half = data[len(data)//2:]
    
    first_mean = mean(first_half)
    second_mean = mean(second_half)
    
    change_percent = ((second_mean - first_mean) / first_mean) * 100 if first_mean > 0 else 0
    
    if change_percent > 5:
        stats['trend'] = 'increasing'
    elif change_percent < -5:
        stats['trend'] = 'decreasing'
    else:
        stats['trend'] = 'stable'
        
    stats['trend_change'] = round(change_percent, 2)
else:
    stats['trend'] = 'insufficient_data'
    stats['trend_change'] = 0

print(json.dumps(stats))
" <<< "$data"
    }
    
    log "Starting Historical Trend Analysis"
    
    # Create analysis timestamp
    analysis_time=$(date +%Y%m%d_%H%M%S)
    
    # Collect historical data for various metrics (24 hours)
    log "Collecting CPU usage trends..."
    cpu_data=$(prometheus_range_query 'round(100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100), 0.1)' '24h' '300')
    cpu_stats=$(echo "$cpu_data" | calculate_stats)
    
    log "Collecting memory usage trends..."
    memory_data=$(prometheus_range_query 'round((1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100, 0.1)' '24h' '300')
    memory_stats=$(echo "$memory_data" | calculate_stats)
    
    log "Collecting disk usage trends..."
    disk_data=$(prometheus_range_query 'round((1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100, 0.1)' '24h' '300')
    disk_stats=$(echo "$disk_data" | calculate_stats)
    
    log "Collecting load average trends..."
    load_data=$(prometheus_range_query 'node_load1' '24h' '300')
    load_stats=$(echo "$load_data" | calculate_stats)
    
    log "Collecting network traffic trends..."
    network_rx_data=$(prometheus_range_query 'round(rate(node_network_receive_bytes_total[5m]) / 1024 / 1024, 0.1)' '24h' '300')
    network_rx_stats=$(echo "$network_rx_data" | calculate_stats)
    
    network_tx_data=$(prometheus_range_query 'round(rate(node_network_transmit_bytes_total[5m]) / 1024 / 1024, 0.1)' '24h' '300')
    network_tx_stats=$(echo "$network_tx_data" | calculate_stats)
    
    log "Collecting disk I/O trends..."
    disk_io_data=$(prometheus_range_query 'round(rate(node_disk_io_time_seconds_total[5m]) * 100, 0.1)' '24h' '300')
    disk_io_stats=$(echo "$disk_io_data" | calculate_stats)
    
    # Create comprehensive predictive analysis prompt
    predictive_prompt="As a systems reliability expert, analyze the following 24-hour historical trends and provide predictive maintenance recommendations:
    
    === HISTORICAL TREND ANALYSIS (24 hours) ===
    
    CPU Usage Trends:
    - Mean: $(echo "$cpu_stats" | jq -r '.mean')%
    - Standard Deviation: $(echo "$cpu_stats" | jq -r '.stdev')%
    - Range: $(echo "$cpu_stats" | jq -r '.min')% - $(echo "$cpu_stats" | jq -r '.max')%
    - Trend: $(echo "$cpu_stats" | jq -r '.trend') ($(echo "$cpu_stats" | jq -r '.trend_change')% change)
    - Samples: $(echo "$cpu_stats" | jq -r '.samples')
    
    Memory Usage Trends:
    - Mean: $(echo "$memory_stats" | jq -r '.mean')%
    - Standard Deviation: $(echo "$memory_stats" | jq -r '.stdev')%
    - Range: $(echo "$memory_stats" | jq -r '.min')% - $(echo "$memory_stats" | jq -r '.max')%
    - Trend: $(echo "$memory_stats" | jq -r '.trend') ($(echo "$memory_stats" | jq -r '.trend_change')% change)
    - Samples: $(echo "$memory_stats" | jq -r '.samples')
    
    Disk Usage Trends:
    - Mean: $(echo "$disk_stats" | jq -r '.mean')%
    - Standard Deviation: $(echo "$disk_stats" | jq -r '.stdev')%
    - Range: $(echo "$disk_stats" | jq -r '.min')% - $(echo "$disk_stats" | jq -r '.max')%
    - Trend: $(echo "$disk_stats" | jq -r '.trend') ($(echo "$disk_stats" | jq -r '.trend_change')% change)
    - Samples: $(echo "$disk_stats" | jq -r '.samples')
    
    Load Average Trends:
    - Mean: $(echo "$load_stats" | jq -r '.mean')
    - Standard Deviation: $(echo "$load_stats" | jq -r '.stdev')
    - Range: $(echo "$load_stats" | jq -r '.min') - $(echo "$load_stats" | jq -r '.max')
    - Trend: $(echo "$load_stats" | jq -r '.trend') ($(echo "$load_stats" | jq -r '.trend_change')% change)
    - Samples: $(echo "$load_stats" | jq -r '.samples')
    
    Network Traffic Trends:
    - RX Mean: $(echo "$network_rx_stats" | jq -r '.mean') MB/s
    - TX Mean: $(echo "$network_tx_stats" | jq -r '.mean') MB/s
    - RX Trend: $(echo "$network_rx_stats" | jq -r '.trend') ($(echo "$network_rx_stats" | jq -r '.trend_change')% change)
    - TX Trend: $(echo "$network_tx_stats" | jq -r '.trend') ($(echo "$network_tx_stats" | jq -r '.trend_change')% change)
    
    Disk I/O Trends:
    - Mean: $(echo "$disk_io_stats" | jq -r '.mean')%
    - Standard Deviation: $(echo "$disk_io_stats" | jq -r '.stdev')%
    - Trend: $(echo "$disk_io_stats" | jq -r '.trend') ($(echo "$disk_io_stats" | jq -r '.trend_change')% change)
    
    === PREDICTIVE MAINTENANCE ANALYSIS REQUIREMENTS ===
    
    1. **Failure Risk Assessment**:
       - Identify metrics showing concerning trends (increasing resource usage, high volatility)
       - Calculate risk scores for each subsystem (CPU, Memory, Disk, Network)
       - Predict potential failure points based on trend extrapolation
    
    2. **Maintenance Scheduling**:
       - Recommend optimal maintenance windows based on usage patterns
       - Suggest preventive actions before issues become critical
       - Prioritize maintenance tasks by urgency and impact
    
    3. **Capacity Planning**:
       - Project future resource needs based on current trends
       - Recommend hardware upgrades or scaling actions
       - Estimate timeline for resource exhaustion
    
    4. **Anomaly Detection**:
       - Identify unusual patterns or outliers in the data
       - Assess if recent changes indicate system degradation
       - Recommend monitoring improvements
    
    5. **Performance Optimization**:
       - Suggest optimizations based on usage patterns
       - Recommend configuration changes for better efficiency
       - Identify underutilized resources
    
    === OUTPUT FORMAT ===
    
    Provide structured recommendations with:
    - **Risk Level**: Critical/High/Medium/Low for each subsystem
    - **Maintenance Priority**: Immediate/Urgent/Scheduled/Routine
    - **Predicted Timeline**: When issues might occur (hours/days/weeks)
    - **Specific Actions**: Detailed maintenance tasks and optimizations
    - **Monitoring Recommendations**: What to watch more closely
    
    Focus on actionable insights that can prevent system failures and optimize performance."
    
    # Get AI predictive analysis
    log "Querying AI for predictive maintenance analysis..."
    predictive_result=$(ai_query "$predictive_prompt")
    
    if [ $? -eq 0 ] && [ -n "$predictive_result" ]; then
        # Save predictive analysis results
        output_file="$OUTPUT_PATH/predictive/trend_analysis_$analysis_time.txt"
        mkdir -p "$(dirname "$output_file")"
        
        {
            echo "=== AI Predictive Maintenance Analysis ==="
            echo "Generated: $(date)"
            echo "Host: $(hostname)"
            echo "Analysis Period: 24 hours"
            echo "AI Provider: $AI_PROVIDER"
            echo ""
            echo "=== HISTORICAL TREND STATISTICS ==="
            echo "CPU Usage: Mean=$(echo "$cpu_stats" | jq -r '.mean')%, Trend=$(echo "$cpu_stats" | jq -r '.trend')"
            echo "Memory Usage: Mean=$(echo "$memory_stats" | jq -r '.mean')%, Trend=$(echo "$memory_stats" | jq -r '.trend')"
            echo "Disk Usage: Mean=$(echo "$disk_stats" | jq -r '.mean')%, Trend=$(echo "$disk_stats" | jq -r '.trend')"
            echo "Load Average: Mean=$(echo "$load_stats" | jq -r '.mean'), Trend=$(echo "$load_stats" | jq -r '.trend')"
            echo "Network RX: Mean=$(echo "$network_rx_stats" | jq -r '.mean') MB/s, Trend=$(echo "$network_rx_stats" | jq -r '.trend')"
            echo "Network TX: Mean=$(echo "$network_tx_stats" | jq -r '.mean') MB/s, Trend=$(echo "$network_tx_stats" | jq -r '.trend')"
            echo "Disk I/O: Mean=$(echo "$disk_io_stats" | jq -r '.mean')%, Trend=$(echo "$disk_io_stats" | jq -r '.trend')"
            echo ""
            echo "=== PREDICTIVE MAINTENANCE RECOMMENDATIONS ==="
            echo "$predictive_result"
            echo ""
            echo "=== RAW STATISTICS ==="
            echo "CPU Statistics: $cpu_stats"
            echo "Memory Statistics: $memory_stats"
            echo "Disk Statistics: $disk_stats"
            echo "Load Statistics: $load_stats"
            echo "Network RX Statistics: $network_rx_stats"
            echo "Network TX Statistics: $network_tx_stats"
            echo "Disk I/O Statistics: $disk_io_stats"
        } > "$output_file"
        
        log "Predictive analysis completed and saved to $output_file"
        echo "Predictive maintenance analysis saved to: $output_file"
        
        # Create maintenance schedule summary
        schedule_file="$OUTPUT_PATH/predictive/maintenance_schedule.txt"
        {
            echo "=== Maintenance Schedule Summary ==="
            echo "Generated: $(date)"
            echo "Next Analysis: $(date -d '+12 hours')"
            echo ""
            echo "Based on latest trend analysis:"
            echo "- CPU Trend: $(echo "$cpu_stats" | jq -r '.trend')"
            echo "- Memory Trend: $(echo "$memory_stats" | jq -r '.trend')"
            echo "- Disk Trend: $(echo "$disk_stats" | jq -r '.trend')"
            echo "- Load Trend: $(echo "$load_stats" | jq -r '.trend')"
            echo ""
            echo "Full report: $output_file"
        } > "$schedule_file"
        
    else
        log "ERROR: Failed to get AI predictive analysis"
        exit 1
    fi
  '';
  
  # Failure prediction script
  failurePredictionScript = pkgs.writeShellScriptBin "ai-failure-prediction" ''
    set -euo pipefail
    
    export PATH="${lib.makeBinPath (with pkgs; [ curl jq coreutils util-linux bc python3 ])}"
    export OUTPUT_PATH="''${OUTPUT_PATH:-/var/lib/ai-analysis}"
    export LOG_FILE="/var/log/ai-analysis/failure-prediction.log"
    
    # Logging function
    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
    }
    
    # Prometheus query function
    prometheus_query() {
        local query="$1"
        local monitoring_url="''${MONITORING_URL:-http://dex5550:9090}"
        
        curl -s -G "$monitoring_url/api/v1/query" \
            --data-urlencode "query=$query" \
            --data-urlencode "time=$(date +%s)" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0"
    }
    
    # Failure prediction algorithm
    predict_failures() {
        python3 -c "
import sys
import json
from datetime import datetime, timedelta

# System thresholds for failure prediction
CRITICAL_THRESHOLDS = {
    'cpu': 95,
    'memory': 95,
    'disk': 98,
    'load': 8.0,
    'disk_io': 90
}

WARNING_THRESHOLDS = {
    'cpu': 85,
    'memory': 85,
    'disk': 90,
    'load': 4.0,
    'disk_io': 70
}

# Read metrics from command line arguments
cpu_usage = float(sys.argv[1])
memory_usage = float(sys.argv[2])
disk_usage = float(sys.argv[3])
load_avg = float(sys.argv[4])
disk_io = float(sys.argv[5])

predictions = []
risk_score = 0

# CPU failure prediction
if cpu_usage >= CRITICAL_THRESHOLDS['cpu']:
    predictions.append({
        'component': 'CPU',
        'risk': 'CRITICAL',
        'current_value': cpu_usage,
        'threshold': CRITICAL_THRESHOLDS['cpu'],
        'eta': '< 1 hour',
        'action': 'Immediate CPU optimization or scaling required'
    })
    risk_score += 40
elif cpu_usage >= WARNING_THRESHOLDS['cpu']:
    predictions.append({
        'component': 'CPU',
        'risk': 'WARNING',
        'current_value': cpu_usage,
        'threshold': WARNING_THRESHOLDS['cpu'],
        'eta': '1-6 hours',
        'action': 'Monitor CPU usage closely, consider optimization'
    })
    risk_score += 20

# Memory failure prediction
if memory_usage >= CRITICAL_THRESHOLDS['memory']:
    predictions.append({
        'component': 'Memory',
        'risk': 'CRITICAL',
        'current_value': memory_usage,
        'threshold': CRITICAL_THRESHOLDS['memory'],
        'eta': '< 30 minutes',
        'action': 'Immediate memory cleanup or restart required'
    })
    risk_score += 35
elif memory_usage >= WARNING_THRESHOLDS['memory']:
    predictions.append({
        'component': 'Memory',
        'risk': 'WARNING',
        'current_value': memory_usage,
        'threshold': WARNING_THRESHOLDS['memory'],
        'eta': '1-3 hours',
        'action': 'Clear memory caches, restart heavy services'
    })
    risk_score += 15

# Disk failure prediction
if disk_usage >= CRITICAL_THRESHOLDS['disk']:
    predictions.append({
        'component': 'Disk',
        'risk': 'CRITICAL',
        'current_value': disk_usage,
        'threshold': CRITICAL_THRESHOLDS['disk'],
        'eta': '< 2 hours',
        'action': 'Immediate disk cleanup required'
    })
    risk_score += 30
elif disk_usage >= WARNING_THRESHOLDS['disk']:
    predictions.append({
        'component': 'Disk',
        'risk': 'WARNING',
        'current_value': disk_usage,
        'threshold': WARNING_THRESHOLDS['disk'],
        'eta': '6-24 hours',
        'action': 'Schedule disk cleanup, monitor growth'
    })
    risk_score += 10

# Load average failure prediction
if load_avg >= CRITICAL_THRESHOLDS['load']:
    predictions.append({
        'component': 'System Load',
        'risk': 'CRITICAL',
        'current_value': load_avg,
        'threshold': CRITICAL_THRESHOLDS['load'],
        'eta': '< 15 minutes',
        'action': 'System overload - reduce processes immediately'
    })
    risk_score += 25
elif load_avg >= WARNING_THRESHOLDS['load']:
    predictions.append({
        'component': 'System Load',
        'risk': 'WARNING',
        'current_value': load_avg,
        'threshold': WARNING_THRESHOLDS['load'],
        'eta': '30 minutes - 2 hours',
        'action': 'Monitor system load, consider process optimization'
    })
    risk_score += 10

# Disk I/O failure prediction
if disk_io >= CRITICAL_THRESHOLDS['disk_io']:
    predictions.append({
        'component': 'Disk I/O',
        'risk': 'CRITICAL',
        'current_value': disk_io,
        'threshold': CRITICAL_THRESHOLDS['disk_io'],
        'eta': '< 1 hour',
        'action': 'Disk I/O bottleneck - check processes and storage'
    })
    risk_score += 20
elif disk_io >= WARNING_THRESHOLDS['disk_io']:
    predictions.append({
        'component': 'Disk I/O',
        'risk': 'WARNING',
        'current_value': disk_io,
        'threshold': WARNING_THRESHOLDS['disk_io'],
        'eta': '2-6 hours',
        'action': 'Monitor disk I/O patterns, optimize if needed'
    })
    risk_score += 8

# Overall system health assessment
if risk_score >= 80:
    health_status = 'CRITICAL'
elif risk_score >= 40:
    health_status = 'WARNING'
elif risk_score >= 20:
    health_status = 'ATTENTION'
else:
    health_status = 'HEALTHY'

result = {
    'timestamp': datetime.now().isoformat(),
    'overall_risk_score': risk_score,
    'health_status': health_status,
    'predictions': predictions
}

print(json.dumps(result, indent=2))
"
    }
    
    log "Starting Failure Prediction Analysis"
    
    # Collect current metrics
    cpu_usage=$(prometheus_query 'round(100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100), 0.1)')
    memory_usage=$(prometheus_query 'round((1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100, 0.1)')
    disk_usage=$(prometheus_query 'round((1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100, 0.1)')
    load_avg=$(prometheus_query 'node_load1')
    disk_io=$(prometheus_query 'round(rate(node_disk_io_time_seconds_total[5m]) * 100, 0.1)')
    
    log "Current metrics - CPU: $cpu_usage%, Memory: $memory_usage%, Disk: $disk_usage%, Load: $load_avg, Disk I/O: $disk_io%"
    
    # Run failure prediction algorithm
    prediction_result=$(predict_failures "$cpu_usage" "$memory_usage" "$disk_usage" "$load_avg" "$disk_io")
    
    # Save prediction results
    output_file="$OUTPUT_PATH/predictive/failure_prediction_$(date +%Y%m%d_%H%M%S).json"
    mkdir -p "$(dirname "$output_file")"
    
    echo "$prediction_result" > "$output_file"
    
    # Create human-readable summary
    summary_file="$OUTPUT_PATH/predictive/failure_summary.txt"
    {
        echo "=== System Failure Prediction Summary ==="
        echo "Generated: $(date)"
        echo "Host: $(hostname)"
        echo ""
        echo "Overall Risk Score: $(echo "$prediction_result" | jq -r '.overall_risk_score')/100"
        echo "Health Status: $(echo "$prediction_result" | jq -r '.health_status')"
        echo ""
        echo "Current Metrics:"
        echo "- CPU Usage: $cpu_usage%"
        echo "- Memory Usage: $memory_usage%"
        echo "- Disk Usage: $disk_usage%"
        echo "- Load Average: $load_avg"
        echo "- Disk I/O: $disk_io%"
        echo ""
        echo "Failure Predictions:"
        echo "$prediction_result" | jq -r '.predictions[] | "- \(.component): \(.risk) (ETA: \(.eta)) - \(.action)"'
        echo ""
        echo "Raw data: $output_file"
    } > "$summary_file"
    
    log "Failure prediction analysis completed"
    echo "Failure prediction saved to: $output_file"
    cat "$summary_file"
  '';
  
  # Maintenance scheduler script
  maintenanceSchedulerScript = pkgs.writeShellScriptBin "ai-maintenance-scheduler" ''
    set -euo pipefail
    
    export PATH="${lib.makeBinPath (with pkgs; [ curl jq coreutils util-linux bc ])}"
    export OUTPUT_PATH="''${OUTPUT_PATH:-/var/lib/ai-analysis}"
    export LOG_FILE="/var/log/ai-analysis/maintenance.log"
    
    # Logging function
    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
    }
    
    log "Starting Maintenance Scheduler"
    
    # Check for recent failure predictions
    prediction_dir="$OUTPUT_PATH/predictive"
    if [ -d "$prediction_dir" ]; then
        latest_prediction=$(ls -t "$prediction_dir"/failure_prediction_*.json 2>/dev/null | head -1)
        if [ -n "$latest_prediction" ]; then
            risk_score=$(jq -r '.overall_risk_score' "$latest_prediction")
            health_status=$(jq -r '.health_status' "$latest_prediction")
            
            log "Latest risk score: $risk_score, Health: $health_status"
            
            # Generate maintenance schedule based on risk
            schedule_file="$OUTPUT_PATH/predictive/maintenance_schedule_$(date +%Y%m%d_%H%M%S).txt"
            {
                echo "=== Automated Maintenance Schedule ==="
                echo "Generated: $(date)"
                echo "Based on Risk Score: $risk_score"
                echo "System Health: $health_status"
                echo ""
                
                case "$health_status" in
                    "CRITICAL")
                        echo "🚨 IMMEDIATE MAINTENANCE REQUIRED"
                        echo "Schedule: Within next 30 minutes"
                        echo "Actions:"
                        echo "  1. Stop non-essential services"
                        echo "  2. Clear system caches"
                        echo "  3. Check disk space and clean up"
                        echo "  4. Monitor system closely"
                        echo "  5. Consider system restart if needed"
                        ;;
                    "WARNING")
                        echo "⚠️  URGENT MAINTENANCE NEEDED"
                        echo "Schedule: Within next 2 hours"
                        echo "Actions:"
                        echo "  1. Schedule maintenance window"
                        echo "  2. Clean up temporary files"
                        echo "  3. Optimize running processes"
                        echo "  4. Check system logs"
                        echo "  5. Plan capacity upgrades"
                        ;;
                    "ATTENTION")
                        echo "📋 ROUTINE MAINTENANCE RECOMMENDED"
                        echo "Schedule: Within next 24 hours"
                        echo "Actions:"
                        echo "  1. Run system cleanup"
                        echo "  2. Update system packages"
                        echo "  3. Check backup integrity"
                        echo "  4. Review system performance"
                        echo "  5. Update monitoring thresholds"
                        ;;
                    "HEALTHY")
                        echo "✅ SYSTEM HEALTHY"
                        echo "Schedule: Regular maintenance cycle"
                        echo "Actions:"
                        echo "  1. Continue regular monitoring"
                        echo "  2. Weekly system updates"
                        echo "  3. Monthly performance review"
                        echo "  4. Quarterly capacity planning"
                        echo "  5. Annual hardware assessment"
                        ;;
                esac
                
                echo ""
                echo "Detailed predictions:"
                jq -r '.predictions[] | "- \(.component): \(.risk) - \(.action)"' "$latest_prediction"
                
            } > "$schedule_file"
            
            log "Maintenance schedule created: $schedule_file"
            cat "$schedule_file"
        else
            log "No recent failure predictions found"
        fi
    else
        log "Prediction directory not found: $prediction_dir"
    fi
  '';

in {
  config = mkIf cfg.enable {
    # Install predictive maintenance tools
    environment.systemPackages = with pkgs; [
      trendAnalysisScript
      failurePredictionScript
      maintenanceSchedulerScript
    ];
    
    # Create predictive analysis directories
    systemd.tmpfiles.rules = [
      "d ${cfg.outputPath}/predictive 0755 ai-analysis ai-analysis -"
    ];
    
    # Predictive maintenance services
    systemd.services = {
      # Trend analysis service
      ai-trend-analysis = {
        description = "AI Historical Trend Analysis";
        after = [ "network.target" ];
        
        serviceConfig = {
          Type = "oneshot";
          User = "ai-analysis";
          Group = "ai-analysis";
          ExecStart = "${trendAnalysisScript}/bin/ai-trend-analysis";
          
          # Environment variables
          Environment = [
            "AI_PROVIDER=${cfg.aiProvider}"
            "MONITORING_URL=http://dex5550:9090"
            "OUTPUT_PATH=${cfg.outputPath}"
            "PATH=/run/current-system/sw/bin:/run/wrappers/bin"
            "AI_PROVIDERS_CONFIG=/etc/ai-providers.json"
            "AI_DEFAULT_PROVIDER=${cfg.aiProvider}"
          ];
          
          # Security hardening
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          RestrictRealtime = true;
          RestrictNamespaces = true;
          LockPersonality = true;
          
          # Resource limits
          MemoryMax = "512M";
          CPUQuota = "50%";
          
          # Writable paths
          ReadWritePaths = [
            cfg.outputPath
            "/var/log/ai-analysis"
          ];
        };
      };
      
      # Failure prediction service
      ai-failure-prediction = {
        description = "AI Failure Prediction Analysis";
        after = [ "network.target" ];
        
        serviceConfig = {
          Type = "oneshot";
          User = "ai-analysis";
          Group = "ai-analysis";
          ExecStart = "${failurePredictionScript}/bin/ai-failure-prediction";
          
          # Environment variables
          Environment = [
            "MONITORING_URL=http://dex5550:9090"
            "OUTPUT_PATH=${cfg.outputPath}"
            "PATH=/run/current-system/sw/bin:/run/wrappers/bin"
          ];
          
          # Security hardening
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          RestrictRealtime = true;
          RestrictNamespaces = true;
          LockPersonality = true;
          
          # Resource limits
          MemoryMax = "256M";
          CPUQuota = "25%";
          
          # Writable paths
          ReadWritePaths = [
            cfg.outputPath
            "/var/log/ai-analysis"
          ];
        };
      };
      
      # Maintenance scheduler service
      ai-maintenance-scheduler = {
        description = "AI Maintenance Scheduler";
        after = [ "network.target" ];
        
        serviceConfig = {
          Type = "oneshot";
          User = "ai-analysis";
          Group = "ai-analysis";
          ExecStart = "${maintenanceSchedulerScript}/bin/ai-maintenance-scheduler";
          
          # Environment variables
          Environment = [
            "OUTPUT_PATH=${cfg.outputPath}"
            "PATH=/run/current-system/sw/bin:/run/wrappers/bin"
          ];
          
          # Security hardening
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          RestrictRealtime = true;
          RestrictNamespaces = true;
          LockPersonality = true;
          
          # Resource limits
          MemoryMax = "128M";
          CPUQuota = "10%";
          
          # Writable paths
          ReadWritePaths = [
            cfg.outputPath
            "/var/log/ai-analysis"
          ];
        };
      };
    };
    
    # Predictive maintenance timers
    systemd.timers = {
      # Trend analysis - twice daily
      ai-trend-analysis = {
        description = "Run AI trend analysis";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*:0/12";  # Every 12 hours
          Persistent = true;
          RandomizedDelaySec = "30min";
        };
      };
      
      # Failure prediction - every 15 minutes
      ai-failure-prediction = {
        description = "Run AI failure prediction";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*:0/15";  # Every 15 minutes
          Persistent = true;
          RandomizedDelaySec = "2min";
        };
      };
      
      # Maintenance scheduler - every 30 minutes
      ai-maintenance-scheduler = {
        description = "Run AI maintenance scheduler";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*:0/30";  # Every 30 minutes
          Persistent = true;
          RandomizedDelaySec = "5min";
        };
      };
    };
    
    # Shell aliases for predictive maintenance
    programs.zsh.shellAliases = mkIf config.programs.zsh.enable {
      "ai-trends" = "ai-trend-analysis";
      "ai-predict" = "ai-failure-prediction";
      "ai-maintenance" = "ai-maintenance-scheduler";
      "ai-predictive" = "ai-trend-analysis && ai-failure-prediction && ai-maintenance-scheduler";
    };
  };
}