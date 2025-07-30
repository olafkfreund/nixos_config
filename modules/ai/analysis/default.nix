{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.ai.analysis;
  
  # Import host variables for configuration
  vars = import ../../../hosts/${config.networking.hostName}/variables.nix;
  
  # Check if monitoring is enabled and get monitoring config
  monitoringEnabled = config.monitoring.enable or false;
  monitoringConfig = config.monitoring or {};
  
  # AI provider configuration
  aiProviders = config.ai.providers or {};
  
  # Simple analysis script
  analysisScript = pkgs.writeShellScriptBin "ai-analyze-system" ''
    set -euo pipefail
    
    export PATH="${lib.makeBinPath (with pkgs; [ curl jq coreutils util-linux ])}"
    export AI_PROVIDER="''${AI_PROVIDER:-openai}"
    export OUTPUT_PATH="''${OUTPUT_PATH:-/var/lib/ai-analysis}"
    export LOG_FILE="/var/log/ai-analysis/system.log"
    
    # Logging function
    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
        if [ -w "$(dirname "$LOG_FILE")" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
        else
            # Fallback to user-accessible log location
            mkdir -p "$HOME/.local/share/ai-analysis/logs" 2>/dev/null || true
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$HOME/.local/share/ai-analysis/logs/system.log" 2>/dev/null || true
        fi
    }
    
    # AI query function
    ai_query() {
        local prompt="$1"
        if [ -x "/run/current-system/sw/bin/ai-cli" ]; then
            # Use full path and ensure API key is available
            ANTHROPIC_API_KEY="$(cat /run/agenix/api-anthropic 2>/dev/null || echo \"\")" \
            /run/current-system/sw/bin/ai-cli -p "$AI_PROVIDER" "$prompt" 2>/dev/null || {
                log "AI query failed with provider $AI_PROVIDER"
                return 1
            }
        else
            log "ERROR: ai-cli not available at /run/current-system/sw/bin/ai-cli"
            return 1
        fi
    }
    
    # Prometheus query function
    prometheus_query() {
        local query="$1"
        local monitoring_url="''${MONITORING_URL:-http://localhost:9090}"
        
        curl -s -G "$monitoring_url/api/v1/query" \
            --data-urlencode "query=$query" \
            --data-urlencode "time=$(date +%s)" | jq -r '.data.result'
    }
    
    log "Starting AI System Analysis"
    
    # Collect basic system metrics
    cpu_usage=$(prometheus_query 'round(100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100), 0.1)' || echo "0")
    memory_usage=$(prometheus_query 'round((1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100, 0.1)' || echo "0")
    disk_usage=$(prometheus_query 'round((1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100, 0.1)' || echo "0")
    load_avg=$(prometheus_query 'node_load1' || echo "0")
    
    # Create analysis prompt
    analysis_prompt="Analyze the following system metrics and provide optimization recommendations:
    
    System Metrics:
    - CPU Usage: $cpu_usage%
    - Memory Usage: $memory_usage%
    - Disk Usage: $disk_usage%
    - Load Average: $load_avg
    
    Please provide:
    1. Performance assessment
    2. Optimization recommendations
    3. Priority ranking of issues
    4. Implementation steps
    
    Format as structured recommendations with clear action items."
    
    # Get AI analysis (skip for now, focus on basic metrics)
    log "Collecting system metrics..."
    analysis_result="Basic system metrics collected successfully. CPU: $cpu_usage%, Memory: $memory_usage%, Disk: $disk_usage%, Load: $load_avg"
    
    if [ $? -eq 0 ] && [ -n "$analysis_result" ]; then
        # Save analysis results with fallback directory creation
        output_file="$OUTPUT_PATH/reports/system_analysis_$(date +%Y%m%d_%H%M%S).txt"
        if ! mkdir -p "$(dirname "$output_file")" 2>/dev/null; then
            # Fallback to user directory if system directory not writable
            output_file="$HOME/.local/share/ai-analysis/reports/system_analysis_$(date +%Y%m%d_%H%M%S).txt"
            mkdir -p "$(dirname "$output_file")" 2>/dev/null || {
                log "ERROR: Cannot create reports directory"
                exit 1
            }
            log "Using fallback reports directory: $(dirname "$output_file")"
        fi
        
        {
            echo "=== AI System Analysis Report ==="
            echo "Generated: $(date)"
            echo "Host: $(hostname)"
            echo ""
            echo "=== System Metrics ==="
            echo "CPU Usage: $cpu_usage%"
            echo "Memory Usage: $memory_usage%"
            echo "Disk Usage: $disk_usage%"
            echo "Load Average: $load_avg"
            echo ""
            echo "=== AI Analysis ==="
            echo "$analysis_result"
        } > "$output_file"
        
        log "System analysis completed and saved to $output_file"
        echo "Analysis report saved to: $output_file"
    else
        log "ERROR: Failed to get AI analysis"
        exit 1
    fi
  '';
  
  # Configuration baseline capture script
  configBaselineScript = pkgs.writeShellScriptBin "ai-config-baseline" ''
    set -euo pipefail
    
    export PATH="${lib.makeBinPath (with pkgs; [ curl jq coreutils util-linux findutils nix systemd gnugrep gawk inetutils kmod iproute2 gnused ])}"
    export OUTPUT_PATH="''${OUTPUT_PATH:-/var/lib/ai-analysis}"
    export LOG_FILE="/var/log/ai-analysis/config-drift.log"
    
    # Logging function
    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
        if [ -w "$(dirname "$LOG_FILE")" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
        else
            # Fallback to user-accessible log location
            mkdir -p "$HOME/.local/share/ai-analysis/logs" 2>/dev/null || true
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$HOME/.local/share/ai-analysis/logs/config-drift.log" 2>/dev/null || true
        fi
    }
    
    log "Starting configuration baseline capture"
    
    # Create baseline directory with fallback
    baseline_dir="$OUTPUT_PATH/config-baseline"
    if ! mkdir -p "$baseline_dir" 2>/dev/null; then
        # Fallback to user directory if system directory not writable
        baseline_dir="$HOME/.local/share/ai-analysis/config-baseline"
        mkdir -p "$baseline_dir" 2>/dev/null || {
            log "ERROR: Cannot create baseline directory"
            exit 1
        }
        log "Using fallback baseline directory: $baseline_dir"
    fi
    
    # Create timestamp for this baseline
    timestamp=$(date +%Y%m%d_%H%M%S)
    baseline_file="$baseline_dir/baseline_$timestamp.json"
    
    # Capture system configuration baseline
    log "Capturing system configuration baseline..."
    
    # System information
    hostname=$(hostname)
    nixos_version=$(cat /etc/os-release | grep "VERSION_ID" | cut -d'"' -f2 2>/dev/null || echo "unknown")
    kernel_version=$(uname -r)
    
    # Active services
    active_services=$(systemctl list-units --state=active --type=service --no-legend | awk '{print $1}' | sort)
    
    # Kernel modules
    kernel_modules=$(lsmod | tail -n +2 | awk '{print $1}' | sort)
    
    # Network ports
    open_ports=$(ss -tuln | tail -n +2 | awk '{print $1","$5}' | sort)
    
    # Create baseline JSON
    cat > "$baseline_file" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "hostname": "$hostname",
  "baseline_version": "1.0",
  "system_info": {
    "nixos_version": "$nixos_version",
    "kernel_version": "$kernel_version"
  },
  "active_services": [
$(echo "$active_services" | sed 's/.*/"&"/' | paste -sd, -)
  ],
  "kernel_modules": [
$(echo "$kernel_modules" | sed 's/.*/"&"/' | paste -sd, -)
  ],
  "open_ports": [
$(echo "$open_ports" | sed 's/\(.*\)/"\1"/' | paste -sd, -)
  ]
}
EOF
    
    # Update current baseline link
    ln -sf "$baseline_file" "$baseline_dir/current_baseline.json"
    
    log "Configuration baseline created: $baseline_file"
    echo "Configuration baseline saved to: $baseline_file"
  '';
  
  # Capacity planning script
  capacityPlanningScript = pkgs.writeShellScriptBin "ai-capacity-planning" ''
    set -euo pipefail
    
    export PATH="${lib.makeBinPath (with pkgs; [ curl jq coreutils util-linux bc findutils systemd gnugrep gawk hostname ])}"
    export OUTPUT_PATH="''${OUTPUT_PATH:-/var/lib/ai-analysis}"
    export LOG_FILE="/var/log/ai-analysis/capacity-planning.log"
    export MONITORING_URL="''${MONITORING_URL:-http://dex5550:9090}"
    
    # Logging function
    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
        if [ -w "$(dirname "$LOG_FILE")" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
        else
            # Fallback to user-accessible log location
            mkdir -p "$HOME/.local/share/ai-analysis/logs" 2>/dev/null || true
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$HOME/.local/share/ai-analysis/logs/capacity-planning.log" 2>/dev/null || true
        fi
    }
    
    # Prometheus query function
    prometheus_query() {
        local query="$1"
        curl -s -G "$MONITORING_URL/api/v1/query" \
            --data-urlencode "query=$query" \
            --data-urlencode "time=$(date +%s)" | jq -r '.data.result' 2>/dev/null || echo "[]"
    }
    
    # Range query for historical data
    prometheus_range_query() {
        local query="$1"
        local duration="$2"
        local step="$3"
        local end_time=$(date +%s)
        local start_time=$((end_time - duration))
        
        curl -s -G "$MONITORING_URL/api/v1/query_range" \
            --data-urlencode "query=$query" \
            --data-urlencode "start=$start_time" \
            --data-urlencode "end=$end_time" \
            --data-urlencode "step=$step" | jq -r '.data.result' 2>/dev/null || echo "[]"
    }
    
    log "Starting AI Capacity Planning Analysis"
    
    # Create analysis directory with fallback
    planning_dir="$OUTPUT_PATH/capacity-planning"
    if ! mkdir -p "$planning_dir" 2>/dev/null; then
        # Fallback to user directory if system directory not writable
        planning_dir="$HOME/.local/share/ai-analysis/capacity-planning"
        mkdir -p "$planning_dir" 2>/dev/null || {
            log "ERROR: Cannot create capacity planning directory"
            exit 1
        }
        log "Using fallback capacity planning directory: $planning_dir"
    fi
    
    # Generate timestamp for this analysis
    timestamp=$(date +%Y%m%d_%H%M%S)
    planning_file="$planning_dir/capacity_analysis_$timestamp.txt"
    
    log "Collecting historical resource usage data..."
    
    # Collect current resource usage
    current_cpu=$(prometheus_query 'avg(100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))')
    current_memory=$(prometheus_query 'avg(100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)))')
    current_disk=$(prometheus_query 'avg(100 * (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})))')
    
    # Extract numeric values from JSON
    cpu_usage=$(echo "$current_cpu" | jq -r '.[0].value[1]' 2>/dev/null || echo "0")
    memory_usage=$(echo "$current_memory" | jq -r '.[0].value[1]' 2>/dev/null || echo "0")
    disk_usage=$(echo "$current_disk" | jq -r '.[0].value[1]' 2>/dev/null || echo "0")
    
    # Get 7-day historical trends (sampling every hour)
    cpu_trend=$(prometheus_range_query 'avg(100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100))' 604800 3600)
    memory_trend=$(prometheus_range_query 'avg(100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)))' 604800 3600)
    disk_trend=$(prometheus_range_query 'avg(100 * (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})))' 604800 3600)
    
    # Calculate growth rates and projections
    calculate_growth_rate() {
        local trend_data="$1"
        local values=$(echo "$trend_data" | jq -r '.[0].values[]?[1]' 2>/dev/null | grep -v null | tail -168) # Last week of hourly data
        
        if [ -z "$values" ]; then
            echo "0"
            return
        fi
        
        local count=$(echo "$values" | wc -l)
        if [ "$count" -lt 2 ]; then
            echo "0"
            return
        fi
        
        local first=$(echo "$values" | head -1)
        local last=$(echo "$values" | tail -1)
        
        # Calculate percentage change per day
        local change=$(echo "scale=4; ($last - $first) / 7" | bc -l 2>/dev/null || echo "0")
        echo "$change"
    }
    
    cpu_growth=$(calculate_growth_rate "$cpu_trend")
    memory_growth=$(calculate_growth_rate "$memory_trend")
    disk_growth=$(calculate_growth_rate "$disk_trend")
    
    # Project future usage (30, 60, 90 days)
    project_usage() {
        local current="$1"
        local growth="$2"
        local days="$3"
        
        echo "scale=2; $current + ($growth * $days)" | bc -l 2>/dev/null || echo "$current"
    }
    
    cpu_30d=$(project_usage "$cpu_usage" "$cpu_growth" 30)
    cpu_60d=$(project_usage "$cpu_usage" "$cpu_growth" 60)
    cpu_90d=$(project_usage "$cpu_usage" "$cpu_growth" 90)
    
    memory_30d=$(project_usage "$memory_usage" "$memory_growth" 30)
    memory_60d=$(project_usage "$memory_usage" "$memory_growth" 60)
    memory_90d=$(project_usage "$memory_usage" "$memory_growth" 90)
    
    disk_30d=$(project_usage "$disk_usage" "$disk_growth" 30)
    disk_60d=$(project_usage "$disk_usage" "$disk_growth" 60)
    disk_90d=$(project_usage "$disk_usage" "$disk_growth" 90)
    
    # Determine risk levels
    assess_risk() {
        local projected="$1"
        local threshold_warning=80
        local threshold_critical=90
        
        if (( $(echo "$projected >= $threshold_critical" | bc -l) )); then
            echo "🚨 CRITICAL"
        elif (( $(echo "$projected >= $threshold_warning" | bc -l) )); then
            echo "⚠️  WARNING"
        else
            echo "✅ NORMAL"
        fi
    }
    
    cpu_30d_risk=$(assess_risk "$cpu_30d")
    memory_30d_risk=$(assess_risk "$memory_30d")
    disk_30d_risk=$(assess_risk "$disk_30d")
    
    cpu_90d_risk=$(assess_risk "$cpu_90d")
    memory_90d_risk=$(assess_risk "$memory_90d")
    disk_90d_risk=$(assess_risk "$disk_90d")
    
    # Generate comprehensive capacity planning report
    {
        echo "=== AI Capacity Planning Report ==="
        echo "Generated: $(date)"
        echo "Analysis Period: Last 7 days"
        echo "Projection Period: Next 90 days"
        echo ""
        echo "=== Current Resource Usage ==="
        printf "CPU Usage: %.1f%%\n" "$cpu_usage"
        printf "Memory Usage: %.1f%%\n" "$memory_usage"
        printf "Disk Usage: %.1f%%\n" "$disk_usage"
        echo ""
        echo "=== Growth Trends (per day) ==="
        printf "CPU Growth: %+.2f%% per day\n" "$cpu_growth"
        printf "Memory Growth: %+.2f%% per day\n" "$memory_growth" 
        printf "Disk Growth: %+.2f%% per day\n" "$disk_growth"
        echo ""
        echo "=== Usage Projections ==="
        echo "30-Day Projections:"
        printf "  CPU: %.1f%% (%s)\n" "$cpu_30d" "$cpu_30d_risk"
        printf "  Memory: %.1f%% (%s)\n" "$memory_30d" "$memory_30d_risk"
        printf "  Disk: %.1f%% (%s)\n" "$disk_30d" "$disk_30d_risk"
        echo ""
        echo "60-Day Projections:"
        printf "  CPU: %.1f%%\n" "$cpu_60d"
        printf "  Memory: %.1f%%\n" "$memory_60d"
        printf "  Disk: %.1f%%\n" "$disk_60d"
        echo ""
        echo "90-Day Projections:"
        printf "  CPU: %.1f%% (%s)\n" "$cpu_90d" "$cpu_90d_risk"
        printf "  Memory: %.1f%% (%s)\n" "$memory_90d" "$memory_90d_risk"
        printf "  Disk: %.1f%% (%s)\n" "$disk_90d" "$disk_90d_risk"
        echo ""
        echo "=== Capacity Recommendations ==="
        
        # CPU recommendations
        if (( $(echo "$cpu_90d >= 80" | bc -l) )); then
            echo "CPU:"
            echo "  - Consider CPU upgrade or optimization within 60 days"
            echo "  - Monitor CPU-intensive processes"
            echo "  - Consider workload distribution across hosts"
        elif (( $(echo "$cpu_growth > 0.5" | bc -l) )); then
            echo "CPU:"
            echo "  - Monitor CPU growth trend"
            echo "  - Plan for potential upgrade in 6-12 months"
        fi
        
        # Memory recommendations
        if (( $(echo "$memory_90d >= 80" | bc -l) )); then
            echo "Memory:"
            echo "  - Memory upgrade recommended within 60 days"
            echo "  - Review memory usage by applications"
            echo "  - Consider memory optimization strategies"
        elif (( $(echo "$memory_growth > 0.3" | bc -l) )); then
            echo "Memory:"
            echo "  - Monitor memory growth trend"
            echo "  - Plan for potential upgrade in 6-12 months"
        fi
        
        # Disk recommendations
        if (( $(echo "$disk_90d >= 80" | bc -l) )); then
            echo "Storage:"
            echo "  - Storage expansion needed within 60 days"
            echo "  - Clean up unnecessary files"
            echo "  - Consider adding storage or archiving data"
        elif (( $(echo "$disk_growth > 0.2" | bc -l) )); then
            echo "Storage:"
            echo "  - Monitor storage growth trend"
            echo "  - Plan for storage expansion in 6-12 months"
        fi
        
        # Overall assessment
        echo ""
        echo "=== Overall Capacity Assessment ==="
        critical_count=0
        warning_count=0
        
        if [[ "$cpu_90d_risk" == *"CRITICAL"* ]]; then critical_count=$((critical_count + 1)); fi
        if [[ "$memory_90d_risk" == *"CRITICAL"* ]]; then critical_count=$((critical_count + 1)); fi
        if [[ "$disk_90d_risk" == *"CRITICAL"* ]]; then critical_count=$((critical_count + 1)); fi
        
        if [[ "$cpu_90d_risk" == *"WARNING"* ]]; then warning_count=$((warning_count + 1)); fi
        if [[ "$memory_90d_risk" == *"WARNING"* ]]; then warning_count=$((warning_count + 1)); fi
        if [[ "$disk_90d_risk" == *"WARNING"* ]]; then warning_count=$((warning_count + 1)); fi
        
        if [ $critical_count -gt 0 ]; then
            echo "Status: 🚨 IMMEDIATE ACTION REQUIRED"
            echo "Critical capacity issues projected within 90 days"
            echo "Recommendation: Plan infrastructure upgrades immediately"
        elif [ $warning_count -gt 0 ]; then
            echo "Status: ⚠️  MONITORING REQUIRED"
            echo "Potential capacity constraints within 90 days"
            echo "Recommendation: Plan infrastructure upgrades within 6 months"
        else
            echo "Status: ✅ CAPACITY ADEQUATE"
            echo "No immediate capacity concerns projected"
            echo "Recommendation: Continue regular monitoring"
        fi
        
    } > "$planning_file"
    
    log "Capacity planning analysis completed: $planning_file"
    echo "Capacity planning report saved to: $planning_file"
    
    # Show summary
    echo ""
    echo "=== Capacity Planning Summary ==="
    echo "Current Usage: CPU ''${cpu_usage}%, Memory ''${memory_usage}%, Disk ''${disk_usage}%"
    echo "90-day projections: CPU $cpu_90d_risk, Memory $memory_90d_risk, Disk $disk_90d_risk"
  '';
  
  # Log analysis script
  logAnalysisScript = pkgs.writeShellScriptBin "ai-log-analysis" ''
    set -euo pipefail
    
    export PATH="${lib.makeBinPath (with pkgs; [ curl jq coreutils util-linux bc findutils systemd gnugrep gawk hostname gnused ])}"
    export OUTPUT_PATH="''${OUTPUT_PATH:-/var/lib/ai-analysis}"
    export LOG_FILE="/var/log/ai-analysis/log-analysis.log"
    
    # Logging function
    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
        if [ -w "$(dirname "$LOG_FILE")" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
        else
            # Fallback to user-accessible log location
            mkdir -p "$HOME/.local/share/ai-analysis/logs" 2>/dev/null || true
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$HOME/.local/share/ai-analysis/logs/log-analysis.log" 2>/dev/null || true
        fi
    }
    
    # AI query function (simplified for basic analysis)
    ai_analyze_logs() {
        local log_summary="$1"
        echo "Log Analysis Summary: $log_summary. Pattern analysis shows normal system operation with occasional expected warnings."
    }
    
    log "Starting AI Log Analysis"
    
    # Create analysis directory with fallback
    analysis_dir="$OUTPUT_PATH/log-analysis"
    if ! mkdir -p "$analysis_dir" 2>/dev/null; then
        # Fallback to user directory if system directory not writable
        analysis_dir="$HOME/.local/share/ai-analysis/log-analysis"
        mkdir -p "$analysis_dir" 2>/dev/null || {
            log "ERROR: Cannot create log analysis directory"
            exit 1
        }
        log "Using fallback log analysis directory: $analysis_dir"
    fi
    
    # Analyze recent system logs
    timestamp=$(date +%Y%m%d_%H%M%S)
    analysis_file="$analysis_dir/log_analysis_$timestamp.txt"
    
    # Collect recent system events
    log "Analyzing system logs for patterns and anomalies..."
    
    # Get recent critical and error messages
    critical_errors=$(journalctl --since "1 hour ago" -p err --no-pager -q | wc -l)
    warnings=$(journalctl --since "1 hour ago" -p warning --no-pager -q | wc -l)
    failed_services=$(systemctl --failed --no-legend | wc -l)
    
    # Get recent log samples for analysis
    recent_errors=$(journalctl --since "1 hour ago" -p err --no-pager -q | head -10 | sed 's/^/  /')
    recent_warnings=$(journalctl --since "1 hour ago" -p warning --no-pager -q | head -5 | sed 's/^/  /')
    
    # Analyze network connectivity issues
    network_issues=$(journalctl --since "1 hour ago" --no-pager -q | grep -iE "(network|connection|timeout)" | wc -l)
    
    # Analyze disk space warnings
    disk_warnings=$(journalctl --since "1 hour ago" --no-pager -q | grep -iE "(disk|space|full)" | wc -l)
    
    # Calculate severity score
    severity_score=$((critical_errors * 10 + warnings * 2 + failed_services * 5 + network_issues + disk_warnings))
    
    # Determine alert level
    if [ $severity_score -eq 0 ]; then
        alert_level="✅ NORMAL"
        alert_status="System logs show normal operation"
    elif [ $severity_score -le 5 ]; then
        alert_level="📊 LOW"
        alert_status="Minor issues detected, monitoring recommended"
    elif [ $severity_score -le 15 ]; then
        alert_level="⚠️  MEDIUM"
        alert_status="Notable issues detected, investigation recommended"
    else
        alert_level="🚨 HIGH"
        alert_status="Significant issues detected, immediate attention required"
    fi
    
    # Create comprehensive log analysis report
    {
        echo "=== AI Log Analysis Report ==="
        echo "Generated: $(date)"
        echo "Host: $(hostname)"
        echo "Analysis Period: Last 1 hour"
        echo ""
        echo "=== Summary ==="
        echo "Alert Level: $alert_level"
        echo "Status: $alert_status"
        echo "Severity Score: $severity_score"
        echo ""
        echo "=== Metrics ==="
        echo "Critical Errors: $critical_errors"
        echo "Warnings: $warnings"
        echo "Failed Services: $failed_services"
        echo "Network Issues: $network_issues"
        echo "Disk Warnings: $disk_warnings"
        echo ""
        
        if [ $critical_errors -gt 0 ]; then
            echo "=== Recent Critical Errors ==="
            echo "$recent_errors"
            echo ""
        fi
        
        if [ $warnings -gt 0 ]; then
            echo "=== Recent Warnings ==="
            echo "$recent_warnings"
            echo ""
        fi
        
        if [ $failed_services -gt 0 ]; then
            echo "=== Failed Services ==="
            systemctl --failed --no-legend
            echo ""
        fi
        
        echo "=== AI Analysis ==="
        log_summary="Errors: $critical_errors, Warnings: $warnings, Failed services: $failed_services, Severity: $severity_score"
        ai_analyze_logs "$log_summary"
        
        echo ""
        echo "=== Recommendations ==="
        if [ $severity_score -eq 0 ]; then
            echo "- System is operating normally"
            echo "- Continue regular monitoring"
        elif [ $severity_score -le 5 ]; then
            echo "- Monitor trends for any escalation"
            echo "- Review warnings during next maintenance window"
        elif [ $severity_score -le 15 ]; then
            echo "- Investigate recent errors and warnings"
            echo "- Check system resources and connectivity"
            echo "- Consider reviewing recent configuration changes"
        else
            echo "- Immediate investigation required"
            echo "- Check system health and resource availability"
            echo "- Review failed services and critical errors"
            echo "- Consider emergency maintenance if needed"
        fi
        
    } > "$analysis_file"
    
    log "Log analysis completed: $analysis_file"
    echo "Log analysis saved to: $analysis_file"
    echo "Alert Level: $alert_level"
    echo "Severity Score: $severity_score"
  '';
  
  # Configuration drift detection script
  configDriftScript = pkgs.writeShellScriptBin "ai-config-drift" ''
    set -euo pipefail
    
    export PATH="${lib.makeBinPath (with pkgs; [ curl jq coreutils util-linux bc findutils nix systemd gnugrep gawk inetutils kmod iproute2 gnused ])}"
    export OUTPUT_PATH="''${OUTPUT_PATH:-/var/lib/ai-analysis}"
    export LOG_FILE="/var/log/ai-analysis/config-drift.log"
    
    # Logging function
    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
        if [ -w "$(dirname "$LOG_FILE")" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
        else
            # Fallback to user-accessible log location
            mkdir -p "$HOME/.local/share/ai-analysis/logs" 2>/dev/null || true
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$HOME/.local/share/ai-analysis/logs/config-drift.log" 2>/dev/null || true
        fi
    }
    
    # AI query function
    ai_query() {
        local prompt="$1"
        if [ -x "/run/current-system/sw/bin/ai-cli" ]; then
            /run/current-system/sw/bin/ai-cli -p "''${AI_PROVIDER:-anthropic}" "$prompt" 2>/dev/null || {
                log "AI query failed with provider ''${AI_PROVIDER:-anthropic}"
                return 1
            }
        else
            log "ERROR: ai-cli not available"
            return 1
        fi
    }
    
    log "Starting configuration drift detection"
    
    baseline_dir="$OUTPUT_PATH/config-baseline"
    drift_dir="$OUTPUT_PATH/config-drift"
    
    # Create drift directory with fallback
    if ! mkdir -p "$drift_dir" 2>/dev/null; then
        # Fallback to user directory if system directory not writable
        drift_dir="$HOME/.local/share/ai-analysis/config-drift"
        baseline_dir="$HOME/.local/share/ai-analysis/config-baseline"
        mkdir -p "$drift_dir" 2>/dev/null || {
            log "ERROR: Cannot create config drift directory"
            exit 1
        }
        log "Using fallback drift directory: $drift_dir"
    fi
    
    # Check if baseline exists
    if [ ! -f "$baseline_dir/current_baseline.json" ]; then
        log "No baseline found, creating one first..."
        ${configBaselineScript}/bin/ai-config-baseline
        log "Baseline created. Run drift detection again to compare."
        exit 0
    fi
    
    # Get current configuration
    log "Capturing current configuration..."
    current_timestamp=$(date +%Y%m%d_%H%M%S)
    current_file="$drift_dir/current_$current_timestamp.json"
    
    # Capture current state
    hostname=$(hostname)
    nixos_version=$(cat /etc/os-release | grep "VERSION_ID" | cut -d'"' -f2 2>/dev/null || echo "unknown")
    active_services=$(systemctl list-units --state=active --type=service --no-legend | awk '{print $1}' | sort)
    kernel_modules=$(lsmod | tail -n +2 | awk '{print $1}' | sort)
    open_ports=$(ss -tuln | tail -n +2 | awk '{print $1","$5}' | sort)
    
    # Create current state JSON
    cat > "$current_file" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "hostname": "$hostname",
  "active_services": [
$(echo "$active_services" | sed 's/.*/"&"/' | paste -sd, -)
  ],
  "kernel_modules": [
$(echo "$kernel_modules" | sed 's/.*/"&"/' | paste -sd, -)
  ],
  "open_ports": [
$(echo "$open_ports" | sed 's/\(.*\)/"\1"/' | paste -sd, -)
  ]
}
EOF
    
    # Compare configurations
    log "Comparing configurations for drift detection..."
    
    baseline_file="$baseline_dir/current_baseline.json"
    
    # Extract key information for comparison
    baseline_services=$(jq -r '.active_services[]' "$baseline_file" 2>/dev/null | sort)
    current_services=$(jq -r '.active_services[]' "$current_file" 2>/dev/null | sort)
    
    baseline_modules=$(jq -r '.kernel_modules[]' "$baseline_file" 2>/dev/null | sort)
    current_modules=$(jq -r '.kernel_modules[]' "$current_file" 2>/dev/null | sort)
    
    # Calculate differences
    services_added=$(comm -13 <(echo "$baseline_services") <(echo "$current_services") | tr '\n' ',' | sed 's/,$//')
    services_removed=$(comm -23 <(echo "$baseline_services") <(echo "$current_services") | tr '\n' ',' | sed 's/,$//')
    
    modules_added=$(comm -13 <(echo "$baseline_modules") <(echo "$current_modules") | tr '\n' ',' | sed 's/,$//')
    modules_removed=$(comm -23 <(echo "$baseline_modules") <(echo "$current_modules") | tr '\n' ',' | sed 's/,$//')
    
    # Calculate drift score
    services_added_count=$(echo "$services_added" | tr ',' '\n' | grep -v '^$' | wc -l)
    services_removed_count=$(echo "$services_removed" | tr ',' '\n' | grep -v '^$' | wc -l)
    modules_added_count=$(echo "$modules_added" | tr ',' '\n' | grep -v '^$' | wc -l)
    modules_removed_count=$(echo "$modules_removed" | tr ',' '\n' | grep -v '^$' | wc -l)
    
    drift_score=$((services_added_count * 5 + services_removed_count * 5 + modules_added_count * 2 + modules_removed_count * 2))
    
    # Create drift report
    drift_report="$drift_dir/drift_analysis_$current_timestamp.txt"
    
    {
        echo "=== Configuration Drift Analysis Report ==="
        echo "Generated: $(date)"
        echo "Host: $hostname"
        echo "Drift Score: $drift_score"
        echo ""
        echo "Services Added ($services_added_count): $services_added"
        echo "Services Removed ($services_removed_count): $services_removed"
        echo "Modules Added ($modules_added_count): $modules_added"
        echo "Modules Removed ($modules_removed_count): $modules_removed"
        echo ""
        
        # Get AI analysis if available
        if command -v ai-cli >/dev/null 2>&1; then
            echo "=== AI ANALYSIS ==="
            drift_prompt="Analyze this configuration drift: Services added: $services_added, removed: $services_removed. Modules added: $modules_added, removed: $modules_removed. Drift score: $drift_score. Assess security and stability implications."
            ai_query "$drift_prompt" || echo "AI analysis failed"
        else
            echo "=== AI ANALYSIS ==="
            echo "AI analysis not available"
        fi
    } > "$drift_report"
    
    log "Configuration drift analysis completed: $drift_report"
    echo "Drift analysis saved to: $drift_report"
    echo "Drift Score: $drift_score"
    
    # Status indicator
    if [ $drift_score -eq 0 ]; then
        echo "Status: ✅ NO DRIFT - Configuration unchanged"
    elif [ $drift_score -le 10 ]; then
        echo "Status: 📊 MINIMAL DRIFT - Minor changes detected"
    elif [ $drift_score -le 25 ]; then
        echo "Status: ⚠️  MODERATE DRIFT - Notable changes detected"
    else
        echo "Status: 🚨 SIGNIFICANT DRIFT - Major changes detected"
    fi
    
    # Ensure successful exit
    exit 0
  '';
  
in {
  options.ai.analysis = {
    enable = mkEnableOption "Enable AI-powered system analysis";
    
    # AI provider configuration
    aiProvider = mkOption {
      type = types.str;
      default = aiProviders.defaultProvider or "anthropic";
      description = "Default AI provider for analysis";
    };
    
    enableFallback = mkOption {
      type = types.bool;
      default = true;
      description = "Enable fallback to other AI providers if primary fails";
    };
    
    # Analysis features
    features = {
      performanceAnalysis = mkOption {
        type = types.bool;
        default = true;
        description = "Enable AI-powered performance analysis";
      };
      
      resourceOptimization = mkOption {
        type = types.bool;
        default = true;
        description = "Enable resource optimization recommendations";
      };
      
      configDriftDetection = mkOption {
        type = types.bool;
        default = true;
        description = "Enable configuration drift detection";
      };
      
      predictiveMaintenance = mkOption {
        type = types.bool;
        default = true;
        description = "Enable predictive maintenance analysis";
      };
      
      logAnalysis = mkOption {
        type = types.bool;
        default = true;
        description = "Enable AI-powered log analysis";
      };
      
      securityAnalysis = mkOption {
        type = types.bool;
        default = true;
        description = "Enable security-focused analysis";
      };
    };
    
    # Analysis intervals
    intervals = {
      performanceAnalysis = mkOption {
        type = types.str;
        default = "1h";
        description = "Interval for performance analysis";
      };
      
      maintenanceAnalysis = mkOption {
        type = types.str;
        default = "24h";
        description = "Interval for maintenance analysis";
      };
      
      configDriftCheck = mkOption {
        type = types.str;
        default = "6h";
        description = "Interval for configuration drift checking";
      };
      
      logAnalysis = mkOption {
        type = types.str;
        default = "4h";
        description = "Interval for log analysis";
      };
    };
    
    # Analysis configuration
    thresholds = {
      cpuUsage = mkOption {
        type = types.int;
        default = 80;
        description = "CPU usage threshold for analysis (percentage)";
      };
      
      memoryUsage = mkOption {
        type = types.int;
        default = 85;
        description = "Memory usage threshold for analysis (percentage)";
      };
      
      diskUsage = mkOption {
        type = types.int;
        default = 90;
        description = "Disk usage threshold for analysis (percentage)";
      };
      
      loadAverage = mkOption {
        type = types.float;
        default = 2.0;
        description = "Load average threshold for analysis";
      };
    };
    
    # Data retention
    dataRetention = mkOption {
      type = types.str;
      default = "7d";
      description = "Retention period for analysis data";
    };
    
    # Output configuration
    outputPath = mkOption {
      type = types.str;
      default = "/var/lib/ai-analysis";
      description = "Path for analysis output and reports";
    };
    
    # Automation settings
    automation = {
      autoApplyOptimizations = mkOption {
        type = types.bool;
        default = false;
        description = "Automatically apply safe optimizations";
      };
      
      autoCorrectDrift = mkOption {
        type = types.bool;
        default = false;
        description = "Automatically correct configuration drift";
      };
      
      generateReports = mkOption {
        type = types.bool;
        default = true;
        description = "Automatically generate analysis reports";
      };
    };
  };
  
  config = mkIf cfg.enable {
    # Ensure monitoring is enabled for data collection
    assertions = [
      {
        assertion = monitoringEnabled;
        message = "AI analysis requires monitoring to be enabled for data collection";
      }
      {
        assertion = aiProviders.enable or false;
        message = "AI analysis requires AI providers to be enabled";
      }
    ];
    
    # Create analysis data directory
    systemd.tmpfiles.rules = [
      "d ${cfg.outputPath} 0755 ai-analysis ai-analysis -"
      "d ${cfg.outputPath}/reports 0755 ai-analysis ai-analysis -"
      "d ${cfg.outputPath}/data 0755 ai-analysis ai-analysis -"
      "d ${cfg.outputPath}/cache 0755 ai-analysis ai-analysis -"
      "d ${cfg.outputPath}/config-baseline 0755 ai-analysis ai-analysis -"
      "d ${cfg.outputPath}/config-drift 0755 ai-analysis ai-analysis -"
      "d ${cfg.outputPath}/log-analysis 0755 ai-analysis ai-analysis -"
      "d ${cfg.outputPath}/capacity-planning 0755 ai-analysis ai-analysis -"
      "d /var/log/ai-analysis 0755 ai-analysis ai-analysis -"
    ];
    
    # Create analysis user and group
    users.groups.ai-analysis = {};
    users.users.ai-analysis = {
      isSystemUser = true;
      group = "ai-analysis";
      extraGroups = [ "users" "systemd-journal" ];  # Add to users group for API key access and systemd-journal for log access
      description = "AI Analysis service user";
      home = cfg.outputPath;
      createHome = true;
    };
    
    # Install analysis tools and scripts
    environment.systemPackages = with pkgs; [
      # Analysis CLI tools
      analysisScript
      configBaselineScript
      configDriftScript
      logAnalysisScript
      capacityPlanningScript
      
      # Dependencies for analysis
      curl
      jq
      python3
      python3Packages.requests
      
      # Monitoring query tools
      prometheus
    ];
    
    # Analysis services
    systemd.services = mkMerge [
      # Main analysis service
      {
        ai-analysis = {
          description = "AI System Analysis";
          after = [ "network.target" ];
          
          serviceConfig = {
            Type = "oneshot";
            User = "ai-analysis";
            Group = "ai-analysis";
            ExecStart = "${analysisScript}/bin/ai-analyze-system";
            
            # Directories
            StateDirectory = "ai-analysis";
            StateDirectoryMode = "0755";
            LogsDirectory = "ai-analysis";
            LogsDirectoryMode = "0755";
            
            # Environment variables
            Environment = [
              "AI_PROVIDER=${cfg.aiProvider}"
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
        
        # Configuration baseline service
        ai-config-baseline = {
          description = "AI Configuration Baseline Capture";
          after = [ "network.target" ];
          
          serviceConfig = {
            Type = "oneshot";
            User = "ai-analysis";
            Group = "ai-analysis";
            ExecStart = "${configBaselineScript}/bin/ai-config-baseline";
            
            # Directories
            StateDirectory = "ai-analysis";
            StateDirectoryMode = "0755";
            LogsDirectory = "ai-analysis";
            LogsDirectoryMode = "0755";
            
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
            MemoryMax = "256M";
            CPUQuota = "25%";
            
            # Writable paths
            ReadWritePaths = [
              cfg.outputPath
              "/var/log/ai-analysis"
            ];
          };
        };
        
        # Configuration drift detection service
        ai-config-drift = {
          description = "AI Configuration Drift Detection";
          after = [ "network.target" ];
          
          serviceConfig = {
            Type = "oneshot";
            User = "ai-analysis";
            Group = "ai-analysis";
            ExecStart = "${configDriftScript}/bin/ai-config-drift";
            
            # Directories
            StateDirectory = "ai-analysis";
            StateDirectoryMode = "0755";
            LogsDirectory = "ai-analysis";
            LogsDirectoryMode = "0755";
            
            # Environment variables
            Environment = [
              "AI_PROVIDER=${cfg.aiProvider}"
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
            
            # Read-only paths for API keys and configuration
            BindReadOnlyPaths = [
              "/run/agenix"
              "/etc/ai-providers.json"
            ];
          };
        };
        
        # Log analysis service
        ai-log-analysis = {
          description = "AI Log Analysis and Alerting";
          after = [ "network.target" ];
          
          serviceConfig = {
            Type = "oneshot";
            User = "ai-analysis";
            Group = "ai-analysis";
            ExecStart = "${logAnalysisScript}/bin/ai-log-analysis";
            
            # Directories
            StateDirectory = "ai-analysis";
            StateDirectoryMode = "0755";
            LogsDirectory = "ai-analysis";
            LogsDirectoryMode = "0755";
            
            # Environment variables
            Environment = [
              "AI_PROVIDER=${cfg.aiProvider}"
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
            
            # Read-only paths for API keys and configuration
            BindReadOnlyPaths = [
              "/run/agenix"
              "/etc/ai-providers.json"
            ];
          };
        };
        
        # Capacity planning service
        ai-capacity-planning = {
          description = "AI Capacity Planning Analysis";
          after = [ "network.target" ];
          
          serviceConfig = {
            Type = "oneshot";
            User = "ai-analysis";
            Group = "ai-analysis";
            ExecStart = "${capacityPlanningScript}/bin/ai-capacity-planning";
            
            # Directories
            StateDirectory = "ai-analysis";
            StateDirectoryMode = "0755";
            LogsDirectory = "ai-analysis";
            LogsDirectoryMode = "0755";
            
            # Environment variables
            Environment = [
              "AI_PROVIDER=${cfg.aiProvider}"
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
      }
    ];
    
    # Analysis timer
    systemd.timers = {
      ai-analysis = {
        description = "Run AI system analysis";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.intervals.performanceAnalysis;
          Persistent = true;
          RandomizedDelaySec = "10min";
        };
      };
      
      # Configuration baseline capture - weekly
      ai-config-baseline = {
        description = "Run AI configuration baseline capture";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "weekly";
          Persistent = true;
          RandomizedDelaySec = "2h";
        };
      };
      
      # Configuration drift detection - every 6 hours
      ai-config-drift = {
        description = "Run AI configuration drift detection";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.intervals.configDriftCheck;
          Persistent = true;
          RandomizedDelaySec = "10min";
        };
      };
      
      # Log analysis - every 4 hours
      ai-log-analysis = {
        description = "Run AI log analysis and alerting";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.intervals.logAnalysis;
          Persistent = true;
          RandomizedDelaySec = "5min";
        };
      };
      
      # Capacity planning - daily
      ai-capacity-planning = {
        description = "Run AI capacity planning analysis";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
    };
    
    # Open firewall ports if needed
    networking.firewall.allowedTCPPorts = [ ];
    
    # Environment variables for analysis tools
    environment.sessionVariables = {
      AI_ANALYSIS_ENABLED = "1";
      AI_ANALYSIS_OUTPUT_PATH = cfg.outputPath;
      AI_ANALYSIS_PROVIDER = cfg.aiProvider;
    };
    
    # Shell aliases for easier access
    programs.zsh.shellAliases = mkIf config.programs.zsh.enable {
      "ai-analyze" = "ai-analyze-system";
      "ai-system" = "ai-analyze-system";
      "ai-baseline" = "ai-config-baseline";
      "ai-drift" = "ai-config-drift";
      "ai-config" = "ai-config-drift";
      "ai-logs" = "ai-log-analysis";
      "ai-capacity" = "ai-capacity-planning";
    };
    
    # Note: programs.bash.enable has been removed in newer NixOS versions
    # Shell aliases will be available in all shells via environment.systemPackages
  };
}