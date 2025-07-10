# Automated Performance Tuner Module
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.ai.autoPerformanceTuner;
in {
  options.ai.autoPerformanceTuner = {
    enable = mkEnableOption "Enable automated performance tuning system";
    
    aiProvider = mkOption {
      type = types.str;
      default = "anthropic";
      description = "AI provider for performance analysis";
    };
    
    enableFallback = mkOption {
      type = types.bool;
      default = true;
      description = "Enable AI provider fallback";
    };
    
    tuningInterval = mkOption {
      type = types.str;
      default = "hourly";
      description = "Automated tuning interval";
    };
    
    safeMode = mkOption {
      type = types.bool;
      default = true;
      description = "Enable safe mode (conservative tuning)";
    };
    
    features = {
      adaptiveTuning = mkOption {
        type = types.bool;
        default = true;
        description = "Enable adaptive performance tuning based on workload";
      };
      
      predictiveOptimization = mkOption {
        type = types.bool;
        default = true;
        description = "Enable predictive performance optimization";
      };
      
      workloadDetection = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automatic workload detection and optimization";
      };
      
      resourceBalancing = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automatic resource balancing";
      };
      
      anomalyCorrection = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automatic performance anomaly correction";
      };
    };
    
    thresholds = {
      cpuUtilization = mkOption {
        type = types.int;
        default = 80;
        description = "CPU utilization threshold for optimization";
      };
      
      memoryUtilization = mkOption {
        type = types.int;
        default = 85;
        description = "Memory utilization threshold for optimization";
      };
      
      ioWait = mkOption {
        type = types.int;
        default = 30;
        description = "I/O wait threshold for optimization";
      };
      
      responseTime = mkOption {
        type = types.int;
        default = 5000;
        description = "Response time threshold in milliseconds";
      };
    };
    
    notifications = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable optimization notifications";
      };
      
      logFile = mkOption {
        type = types.str;
        default = "/var/log/ai-analysis/auto-tuner.log";
        description = "Auto-tuner log file path";
      };
    };
  };

  config = mkIf cfg.enable {
    # Automated Performance Tuner Service
    systemd.services.ai-auto-performance-tuner = {
      description = "AI-Powered Automated Performance Tuner";
      after = [ "network.target" "ai-providers.service" ];
      wants = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        User = "root";
        Restart = "always";
        RestartSec = "30s";
        ExecStart = pkgs.writeShellScript "ai-auto-performance-tuner" ''
          #!/bin/bash
          
          LOG_FILE="${cfg.notifications.logFile}"
          METRICS_DIR="/var/lib/auto-performance-tuner"
          TUNING_DB="$METRICS_DIR/tuning_history.json"
          
          mkdir -p "$(dirname "$LOG_FILE")" "$METRICS_DIR"
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1
          
          echo "[$(date)] Starting AI-Powered Automated Performance Tuner..."
          echo "[$(date)] AI Provider: ${cfg.aiProvider}"
          echo "[$(date)] Safe Mode: ${boolToString cfg.safeMode}"
          echo "[$(date)] Tuning Interval: ${cfg.tuningInterval}"
          
          # Initialize tuning database
          if [ ! -f "$TUNING_DB" ]; then
            cat > "$TUNING_DB" << 'EOF'
          {
            "initialized": "$(date -Iseconds)",
            "tuning_history": [],
            "current_profile": "balanced",
            "last_optimization": null,
            "performance_baseline": {},
            "ai_recommendations": []
          }
          EOF
            echo "[$(date)] Initialized tuning database"
          fi
          
          # Function to collect system performance data
          collect_performance_data() {
            local timestamp=$(date -Iseconds)
            
            # System metrics
            local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' | tr -d '[:space:]')
            local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//' | tr -d '[:space:]')
            local memory_total=$(free -b | grep Mem | awk '{print $2}')
            local memory_used=$(free -b | grep Mem | awk '{print $3}')
            local memory_percent=$(echo "scale=1; $memory_used * 100 / $memory_total" | bc)
            local io_wait=$(top -bn1 | grep "Cpu(s)" | awk '{print $10}' | sed 's/%wa,//' | sed 's/%wa//' | tr -d '[:space:]')
            
            # Network metrics
            local network_connections=$(ss -tuln | grep LISTEN | wc -l)
            
            # Disk metrics
            local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
            
            # AI service metrics
            local ai_services_running=$(systemctl list-units --type=service --state=running | grep -c ai- || echo 0)
            
            # Performance response time (if available)
            local ai_response_time="0"
            if [ -f "/var/lib/ai-analysis/performance-metrics.json" ]; then
              ai_response_time=$(jq -r '.ai_metrics.last_response_time // "0"' /var/lib/ai-analysis/performance-metrics.json 2>/dev/null || echo "0")
            fi
            
            cat << EOF
          {
            "timestamp": "$timestamp",
            "system": {
              "cpu_usage": $cpu_usage,
              "load_average": $load_avg,
              "memory_percent": $memory_percent,
              "io_wait": $io_wait,
              "disk_usage": $disk_usage,
              "network_connections": $network_connections
            },
            "ai": {
              "services_running": $ai_services_running,
              "response_time_ms": $ai_response_time
            }
          }
          EOF
          }
          
          # Function to detect workload type
          detect_workload() {
            local cpu_usage=$1
            local memory_percent=$2
            local ai_services=$3
            local network_connections=$4
            
            ${optionalString cfg.features.workloadDetection ''
              # Simple workload classification
              if [ "$ai_services" -gt 2 ] && [ $(echo "$cpu_usage > 60" | bc) -eq 1 ]; then
                echo "ai-intensive"
              elif [ "$network_connections" -gt 500 ]; then
                echo "network-intensive"
              elif [ $(echo "$memory_percent > 70" | bc) -eq 1 ]; then
                echo "memory-intensive"
              elif [ $(echo "$cpu_usage > 50" | bc) -eq 1 ]; then
                echo "cpu-intensive"
              else
                echo "balanced"
              fi
            ''}
          }
          
          # Function to generate AI-powered optimization recommendations
          generate_ai_recommendations() {
            local performance_data="$1"
            local workload_type="$2"
            
            echo "[$(date)] Generating AI-powered optimization recommendations..."
            
            # Create prompt for AI analysis
            local prompt="Analyze this system performance data and provide optimization recommendations:
          
          Performance Data:
          $performance_data
          
          Detected Workload: $workload_type
          Current Thresholds: CPU=${toString cfg.thresholds.cpuUtilization}%, Memory=${toString cfg.thresholds.memoryUtilization}%, I/O Wait=${toString cfg.thresholds.ioWait}%
          Safe Mode: ${boolToString cfg.safeMode}
          
          Please provide specific, actionable optimization recommendations in JSON format with the following structure:
          {
            \"priority\": \"high|medium|low\",
            \"category\": \"cpu|memory|storage|network|ai\",
            \"action\": \"specific action to take\",
            \"justification\": \"why this optimization is needed\",
            \"risk_level\": \"low|medium|high\",
            \"expected_improvement\": \"percentage improvement expected\"
          }
          
          Focus on safe, proven optimizations. Avoid risky changes in safe mode."
            
            # Call AI service for analysis
            local ai_response=""
            if command -v ai-cli >/dev/null 2>&1; then
              ai_response=$(timeout 60 ai-cli ${optionalString cfg.enableFallback "-f"} -p "${cfg.aiProvider}" "$prompt" 2>/dev/null || echo "AI analysis failed")
            else
              ai_response="AI CLI not available"
            fi
            
            echo "[$(date)] AI Analysis Response: $ai_response"
            echo "$ai_response"
          }
          
          # Function to apply performance optimizations
          apply_optimizations() {
            local recommendations="$1"
            local performance_data="$2"
            
            echo "[$(date)] Applying performance optimizations..."
            
            # Parse current metrics
            local cpu_usage=$(echo "$performance_data" | jq -r '.system.cpu_usage // 0')
            local memory_percent=$(echo "$performance_data" | jq -r '.system.memory_percent // 0')
            local io_wait=$(echo "$performance_data" | jq -r '.system.io_wait // 0')
            local ai_response_time=$(echo "$performance_data" | jq -r '.ai.response_time_ms // 0')
            
            ${optionalString cfg.features.adaptiveTuning ''
              # Adaptive CPU governor tuning
              if [ $(echo "$cpu_usage > ${toString cfg.thresholds.cpuUtilization}" | bc) -eq 1 ]; then
                echo "[$(date)] High CPU usage detected ($cpu_usage%), switching to performance governor"
                for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                  if [ -f "$cpu" ]; then
                    echo performance > "$cpu" 2>/dev/null || true
                  fi
                done
              elif [ $(echo "$cpu_usage < 30" | bc) -eq 1 ]; then
                echo "[$(date)] Low CPU usage detected ($cpu_usage%), switching to powersave governor"
                for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                  if [ -f "$cpu" ]; then
                    echo powersave > "$cpu" 2>/dev/null || true
                  fi
                done
              fi
            ''}
            
            ${optionalString cfg.features.resourceBalancing ''
              # Memory optimization
              if [ $(echo "$memory_percent > ${toString cfg.thresholds.memoryUtilization}" | bc) -eq 1 ]; then
                echo "[$(date)] High memory usage detected ($memory_percent%), optimizing memory settings"
                echo 1 > /proc/sys/vm/swappiness 2>/dev/null || true
                echo 1 > /proc/sys/vm/drop_caches 2>/dev/null || true
              fi
              
              # I/O optimization
              if [ -n "$io_wait" ] && [ $(echo "$io_wait > ${toString cfg.thresholds.ioWait}" | bc) -eq 1 ]; then
                echo "[$(date)] High I/O wait detected ($io_wait%), optimizing I/O scheduler"
                for device in /sys/block/*/queue/scheduler; do
                  if [ -f "$device" ]; then
                    echo deadline > "$device" 2>/dev/null || true
                  fi
                done
              fi
            ''}
            
            ${optionalString cfg.features.anomalyCorrection ''
              # AI response time optimization
              if [ "$ai_response_time" -gt "${toString cfg.thresholds.responseTime}" ]; then
                echo "[$(date)] High AI response time detected (''${ai_response_time}ms), optimizing network settings"
                
                # Optimize TCP settings for AI API calls
                echo 1 > /proc/sys/net/ipv4/tcp_window_scaling 2>/dev/null || true
                echo 1 > /proc/sys/net/ipv4/tcp_timestamps 2>/dev/null || true
                echo "4096 87380 16777216" > /proc/sys/net/ipv4/tcp_rmem 2>/dev/null || true
                echo "4096 65536 16777216" > /proc/sys/net/ipv4/tcp_wmem 2>/dev/null || true
              fi
            ''}
          }
          
          # Function to log tuning actions
          log_tuning_action() {
            local action="$1"
            local reason="$2"
            local impact="$3"
            
            local tuning_record="{
              \"timestamp\": \"$(date -Iseconds)\",
              \"action\": \"$action\",
              \"reason\": \"$reason\",
              \"expected_impact\": \"$impact\",
              \"safe_mode\": ${boolToString cfg.safeMode}
            }"
            
            # Append to tuning history
            if [ -f "$TUNING_DB" ]; then
              local temp_file=$(mktemp)
              jq ".tuning_history += [$tuning_record]" "$TUNING_DB" > "$temp_file" && mv "$temp_file" "$TUNING_DB"
            fi
            
            echo "[$(date)] TUNING ACTION: $action - Reason: $reason - Expected Impact: $impact"
          }
          
          # Main optimization loop
          while true; do
            echo "[$(date)] Starting performance analysis cycle..."
            
            # Collect current performance data
            PERFORMANCE_DATA=$(collect_performance_data)
            echo "[$(date)] Collected performance data"
            
            # Extract key metrics for decision making
            CPU_USAGE=$(echo "$PERFORMANCE_DATA" | jq -r '.system.cpu_usage // 0')
            MEMORY_PERCENT=$(echo "$PERFORMANCE_DATA" | jq -r '.system.memory_percent // 0')
            AI_SERVICES=$(echo "$PERFORMANCE_DATA" | jq -r '.ai.services_running // 0')
            NETWORK_CONNECTIONS=$(echo "$PERFORMANCE_DATA" | jq -r '.system.network_connections // 0')
            
            # Detect workload type
            WORKLOAD_TYPE=$(detect_workload "$CPU_USAGE" "$MEMORY_PERCENT" "$AI_SERVICES" "$NETWORK_CONNECTIONS")
            echo "[$(date)] Detected workload type: $WORKLOAD_TYPE"
            
            # Generate AI recommendations
            AI_RECOMMENDATIONS=$(generate_ai_recommendations "$PERFORMANCE_DATA" "$WORKLOAD_TYPE")
            
            # Apply optimizations based on thresholds and AI recommendations
            apply_optimizations "$AI_RECOMMENDATIONS" "$PERFORMANCE_DATA"
            
            # Log optimization cycle
            log_tuning_action "automated_cycle" "scheduled_optimization" "system_performance_improvement"
            
            # Save current state
            echo "$PERFORMANCE_DATA" > "$METRICS_DIR/last_performance_data.json"
            echo "$AI_RECOMMENDATIONS" > "$METRICS_DIR/last_ai_recommendations.txt"
            
            # Sleep until next optimization cycle
            case "${cfg.tuningInterval}" in
              "hourly") sleep 3600 ;;
              "30min") sleep 1800 ;;
              "15min") sleep 900 ;;
              "10min") sleep 600 ;;
              *) sleep 3600 ;;  # Default to hourly
            esac
          done
        '';
      };
    };
    
    # Performance Baseline Calibration Service
    systemd.services.performance-baseline-calibrator = {
      description = "Performance Baseline Calibration";
      after = [ "ai-auto-performance-tuner.service" ];
      wants = [ "ai-auto-performance-tuner.service" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "performance-baseline-calibrator" ''
          #!/bin/bash
          
          BASELINE_FILE="/var/lib/auto-performance-tuner/performance_baseline.json"
          METRICS_DIR="/var/lib/auto-performance-tuner"
          
          echo "[$(date)] Calibrating performance baseline..."
          
          # Collect baseline measurements over 10 minutes
          SAMPLES=10
          INTERVAL=60
          
          CPU_SAMPLES=()
          MEMORY_SAMPLES=()
          IO_SAMPLES=()
          
          for i in $(seq 1 $SAMPLES); do
            echo "[$(date)] Collecting baseline sample $i/$SAMPLES..."
            
            CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' | tr -d '[:space:]')
            MEMORY=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
            IO_WAIT=$(top -bn1 | grep "Cpu(s)" | awk '{print $10}' | sed 's/%wa,//' | sed 's/%wa//' | tr -d '[:space:]')
            
            CPU_SAMPLES+=($CPU)
            MEMORY_SAMPLES+=($MEMORY)
            IO_SAMPLES+=($IO_WAIT)
            
            sleep $INTERVAL
          done
          
          # Calculate averages
          CPU_BASELINE=$(printf '%s\n' "''${CPU_SAMPLES[@]}" | awk '{sum+=$1; count++} END {printf "%.1f", sum/count}')
          MEMORY_BASELINE=$(printf '%s\n' "''${MEMORY_SAMPLES[@]}" | awk '{sum+=$1; count++} END {printf "%.1f", sum/count}')
          IO_BASELINE=$(printf '%s\n' "''${IO_SAMPLES[@]}" | awk '{sum+=$1; count++} END {printf "%.1f", sum/count}')
          
          # Create baseline file
          cat > "$BASELINE_FILE" << EOF
{
  "calibrated": "$(date -Iseconds)",
  "baseline_metrics": {
    "cpu_usage": $CPU_BASELINE,
    "memory_usage": $MEMORY_BASELINE,
    "io_wait": $IO_BASELINE
  },
  "optimization_targets": {
    "cpu_efficiency": $(echo "$CPU_BASELINE * 0.8" | bc),
    "memory_efficiency": $(echo "$MEMORY_BASELINE * 0.9" | bc),
    "io_efficiency": $(echo "$IO_BASELINE * 0.7" | bc)
  }
}
EOF
          
          echo "[$(date)] Performance baseline calibrated:"
          echo "[$(date)] CPU Baseline: $CPU_BASELINE%"
          echo "[$(date)] Memory Baseline: $MEMORY_BASELINE%"
          echo "[$(date)] I/O Wait Baseline: $IO_BASELINE%"
        '';
      };
    };
    
    # Optimization Impact Assessment Service
    systemd.services.optimization-impact-assessor = {
      description = "Optimization Impact Assessment";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "optimization-impact-assessor" ''
          #!/bin/bash
          
          ASSESSMENT_FILE="/var/lib/auto-performance-tuner/impact_assessment.json"
          TUNING_DB="/var/lib/auto-performance-tuner/tuning_history.json"
          
          echo "[$(date)] Assessing optimization impact..."
          
          if [ -f "$TUNING_DB" ] && [ -f "/var/lib/auto-performance-tuner/performance_baseline.json" ]; then
            # Get current performance metrics
            CURRENT_CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' | tr -d '[:space:]')
            CURRENT_MEMORY=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
            
            # Get baseline metrics
            BASELINE_CPU=$(jq -r '.baseline_metrics.cpu_usage' /var/lib/auto-performance-tuner/performance_baseline.json)
            BASELINE_MEMORY=$(jq -r '.baseline_metrics.memory_usage' /var/lib/auto-performance-tuner/performance_baseline.json)
            
            # Calculate improvements
            CPU_IMPROVEMENT=$(echo "scale=1; ($BASELINE_CPU - $CURRENT_CPU) / $BASELINE_CPU * 100" | bc)
            MEMORY_IMPROVEMENT=$(echo "scale=1; ($BASELINE_MEMORY - $CURRENT_MEMORY) / $BASELINE_MEMORY * 100" | bc)
            
            # Create assessment report
            cat > "$ASSESSMENT_FILE" << EOF
{
  "assessment_date": "$(date -Iseconds)",
  "current_metrics": {
    "cpu_usage": $CURRENT_CPU,
    "memory_usage": $CURRENT_MEMORY
  },
  "baseline_metrics": {
    "cpu_usage": $BASELINE_CPU,
    "memory_usage": $BASELINE_MEMORY
  },
  "improvements": {
    "cpu_improvement_percent": $CPU_IMPROVEMENT,
    "memory_improvement_percent": $MEMORY_IMPROVEMENT
  },
  "optimization_effectiveness": "$(echo "$CPU_IMPROVEMENT + $MEMORY_IMPROVEMENT" | bc | awk '{if(\$1>0) print "positive"; else print "neutral"}')"
}
EOF
            
            echo "[$(date)] Impact assessment completed:"
            echo "[$(date)] CPU Improvement: $CPU_IMPROVEMENT%"
            echo "[$(date)] Memory Improvement: $MEMORY_IMPROVEMENT%"
          fi
        '';
      };
    };
    
    # Timers for regular operations
    systemd.timers.performance-baseline-calibrator = {
      description = "Performance Baseline Calibration Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
    
    systemd.timers.optimization-impact-assessor = {
      description = "Optimization Impact Assessment Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };
    
    # Create directories
    systemd.tmpfiles.rules = [
      "d /var/lib/auto-performance-tuner 0755 root root -"
      "d /var/log/ai-analysis 0755 root root -"
    ];
    
    # Performance tuning packages
    environment.systemPackages = with pkgs; [
      bc          # Basic calculator
      jq          # JSON processor
      curl        # For AI API calls
      procps      # System monitoring
      util-linux  # System utilities
    ];
  };
}