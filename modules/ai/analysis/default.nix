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
    export AI_PROVIDER="''${AI_PROVIDER:-anthropic}"
    export OUTPUT_PATH="''${OUTPUT_PATH:-/var/lib/ai-analysis}"
    export LOG_FILE="/var/log/ai-analysis/system.log"
    
    # Logging function
    log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
    }
    
    # AI query function
    ai_query() {
        local prompt="$1"
        if command -v ai-cli >/dev/null 2>&1; then
            ai-cli -p "$AI_PROVIDER" "$prompt" 2>/dev/null || {
                log "AI query failed with provider $AI_PROVIDER"
                return 1
            }
        else
            log "ERROR: ai-cli not available"
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
    
    # Get AI analysis
    log "Querying AI for system analysis..."
    analysis_result=$(ai_query "$analysis_prompt")
    
    if [ $? -eq 0 ] && [ -n "$analysis_result" ]; then
        # Save analysis results
        output_file="$OUTPUT_PATH/reports/system_analysis_$(date +%Y%m%d_%H%M%S).txt"
        mkdir -p "$(dirname "$output_file")"
        
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
      "d /var/log/ai-analysis 0755 ai-analysis ai-analysis -"
    ];
    
    # Create analysis user and group
    users.groups.ai-analysis = {};
    users.users.ai-analysis = {
      isSystemUser = true;
      group = "ai-analysis";
      description = "AI Analysis service user";
      home = cfg.outputPath;
      createHome = true;
    };
    
    # Install analysis tools and scripts
    environment.systemPackages = with pkgs; [
      # Analysis CLI tools
      analysisScript
      
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
            
            # Environment variables
            Environment = [
              "AI_PROVIDER=${cfg.aiProvider}"
              "MONITORING_URL=http://localhost:${toString monitoringConfig.network.prometheusPort or 9090}"
              "OUTPUT_PATH=${cfg.outputPath}"
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
    };
    
    # Note: programs.bash.enable has been removed in newer NixOS versions
    # Shell aliases will be available in all shells via environment.systemPackages
  };
}