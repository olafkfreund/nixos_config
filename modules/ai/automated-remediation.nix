# Automated Remediation System for AI Analysis Framework
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.ai.automatedRemediation;
in {
  options.ai.automatedRemediation = {
    enable = mkEnableOption "Enable automated remediation system";
    
    enableSelfHealing = mkOption {
      type = types.bool;
      default = false;
      description = "Enable automatic self-healing actions (use with caution)";
    };
    
    safeMode = mkOption {
      type = types.bool;
      default = true;
      description = "Enable safe mode - only non-destructive actions";
    };
    
    notifications = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable notifications for remediation actions";
      };
      
      logFile = mkOption {
        type = types.str;
        default = "/var/log/ai-analysis/remediation.log";
        description = "Log file for remediation actions";
      };
    };
    
    actions = {
      diskCleanup = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automated disk cleanup";
      };
      
      memoryOptimization = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automated memory optimization";
      };
      
      serviceRestart = mkOption {
        type = types.bool;
        default = false;
        description = "Enable automatic service restart for failed services";
      };
      
      configurationReset = mkOption {
        type = types.bool;
        default = false;
        description = "Enable automatic configuration drift correction";
      };
    };
  };

  config = mkIf cfg.enable {
    # Main remediation service
    systemd.services.ai-automated-remediation = {
      description = "AI Automated Remediation Service";
      after = [ "network.target" "prometheus.service" ];
      wants = [ "network.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Environment = [
          "PATH=${lib.makeBinPath (with pkgs; [ coreutils hostname systemd findutils gawk gnugrep gnused curl ])}"
        ];
        ExecStart = pkgs.writeShellScript "ai-automated-remediation" ''
          #!/bin/bash
          
          # Configuration
          LOG_FILE="${cfg.notifications.logFile}"
          SAFE_MODE="${if cfg.safeMode then "true" else "false"}"
          SELF_HEALING="${if cfg.enableSelfHealing then "true" else "false"}"
          PROMETHEUS_URL="http://localhost:9090"
          
          # Ensure log directory exists
          mkdir -p "$(dirname "$LOG_FILE")"
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1
          
          echo "[$(date)] Starting automated remediation system..."
          echo "[$(date)] Safe mode: $SAFE_MODE, Self-healing: $SELF_HEALING"
          
          # Function to query Prometheus
          query_prometheus() {
            local query="$1"
            curl -s -G "$PROMETHEUS_URL/api/v1/query" --data-urlencode "query=$query" 2>/dev/null | \
              jq -r '.data.result[]? | "\(.metric.instance // .metric.job // "unknown"):\(.value[1])"' 2>/dev/null
          }
          
          # Function to send notification
          send_notification() {
            local message="$1"
            local severity="$2"
            echo "[$(date)] [$severity] $message"
            
            # Log to systemd journal
            logger -t ai-remediation "[$severity] $message"
            
            # Future: Could integrate with Slack, email, etc.
          }
          
          # Function to execute remediation action
          execute_action() {
            local action="$1"
            local description="$2"
            local command="$3"
            
            if [ "$SAFE_MODE" = "true" ] && [[ "$action" =~ ^(restart|reset|destructive) ]]; then
              send_notification "SKIPPED: $description (safe mode enabled)" "INFO"
              return 0
            fi
            
            send_notification "EXECUTING: $description" "INFO"
            
            if eval "$command"; then
              send_notification "SUCCESS: $description completed" "INFO"
              return 0
            else
              send_notification "FAILED: $description failed" "ERROR"
              return 1
            fi
          }
          
          # 1. Check and remediate disk space issues
          ${optionalString cfg.actions.diskCleanup ''
          echo "[$(date)] Checking disk space issues..."
          
          # Query disk usage from Prometheus
          disk_usage=$(query_prometheus '100 * (1 - (node_filesystem_avail_bytes{fstype!="tmpfs",fstype!="ramfs",fstype!="squashfs",mountpoint="/"} / node_filesystem_size_bytes{fstype!="tmpfs",fstype!="ramfs",fstype!="squashfs",mountpoint="/"}))' | head -10)
          
          if [ -n "$disk_usage" ]; then
            while IFS=':' read -r instance usage; do
              usage_int=$(echo "$usage" | cut -d. -f1)
              if [ "$usage_int" -gt 85 ]; then
                send_notification "ALERT: Critical disk usage $usage% on $instance" "CRITICAL"
                
                # Execute emergency disk cleanup
                execute_action "disk-cleanup" "Emergency disk cleanup on $instance" "
                  nix-collect-garbage -d --delete-older-than 1d
                  nix-store --optimise
                  find /tmp -type f -atime +1 -delete 2>/dev/null || true
                  find /var/tmp -type f -atime +1 -delete 2>/dev/null || true
                  journalctl --vacuum-size=100M
                  if command -v docker &> /dev/null; then
                    docker system prune -f --volumes
                  fi
                "
              elif [ "$usage_int" -gt 75 ]; then
                send_notification "WARNING: High disk usage $usage% on $instance" "WARNING"
                
                # Execute preventive cleanup
                execute_action "disk-cleanup" "Preventive disk cleanup on $instance" "
                  nix-collect-garbage --delete-older-than 7d
                  nix-store --optimise
                  journalctl --vacuum-size=500M
                "
              fi
            done <<< "$disk_usage"
          fi
          ''}
          
          # 2. Check and remediate memory issues
          ${optionalString cfg.actions.memoryOptimization ''
          echo "[$(date)] Checking memory issues..."
          
          # Query memory usage from Prometheus
          memory_usage=$(query_prometheus '100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))' | head -10)
          
          if [ -n "$memory_usage" ]; then
            while IFS=':' read -r instance usage; do
              usage_int=$(echo "$usage" | cut -d. -f1)
              if [ "$usage_int" -gt 90 ]; then
                send_notification "ALERT: Critical memory usage $usage% on $instance" "CRITICAL"
                
                # Execute emergency memory cleanup
                execute_action "memory-cleanup" "Emergency memory cleanup on $instance" "
                  echo 3 > /proc/sys/vm/drop_caches
                  echo 1 > /proc/sys/vm/compact_memory
                  
                  # Restart memory-intensive services if self-healing is enabled
                  if [ '$SELF_HEALING' = 'true' ]; then
                    systemctl restart grafana || true
                    systemctl restart prometheus || true
                    systemctl restart chromadb || true
                  fi
                "
              elif [ "$usage_int" -gt 80 ]; then
                send_notification "WARNING: High memory usage $usage% on $instance" "WARNING"
                
                # Execute preventive memory optimization
                execute_action "memory-optimization" "Preventive memory optimization on $instance" "
                  echo 1 > /proc/sys/vm/drop_caches
                "
              fi
            done <<< "$memory_usage"
          fi
          ''}
          
          # 3. Check and remediate service failures
          ${optionalString cfg.actions.serviceRestart ''
          echo "[$(date)] Checking service health..."
          
          # Query service health from Prometheus
          services_down=$(query_prometheus 'up{job!="prometheus"} == 0' | head -20)
          
          if [ -n "$services_down" ]; then
            while IFS=':' read -r instance status; do
              service_name=$(echo "$instance" | cut -d. -f1)
              send_notification "ALERT: Service down: $service_name" "CRITICAL"
              
              # Attempt service restart if self-healing is enabled
              if [ "$SELF_HEALING" = "true" ]; then
                case "$service_name" in
                  *grafana*)
                    execute_action "service-restart" "Restart Grafana service" "systemctl restart grafana"
                    ;;
                  *prometheus*)
                    execute_action "service-restart" "Restart Prometheus service" "systemctl restart prometheus"
                    ;;
                  *chromadb*)
                    execute_action "service-restart" "Restart ChromaDB service" "systemctl restart chromadb"
                    ;;
                  *node-exporter*)
                    execute_action "service-restart" "Restart Node Exporter service" "systemctl restart prometheus-node-exporter"
                    ;;
                  *ai-analysis*)
                    execute_action "service-restart" "Restart AI Analysis service" "systemctl restart ai-analysis-system"
                    ;;
                  *)
                    send_notification "INFO: Unknown service $service_name down - manual intervention required" "INFO"
                    ;;
                esac
              else
                send_notification "INFO: Service $service_name down - self-healing disabled" "INFO"
              fi
            done <<< "$services_down"
          fi
          ''}
          
          # 4. Check for configuration drift
          ${optionalString cfg.actions.configurationReset ''
          echo "[$(date)] Checking configuration drift..."
          
          # Query configuration drift from Prometheus
          config_drift=$(query_prometheus 'config_drift_detected > 0' | head -10)
          
          if [ -n "$config_drift" ]; then
            while IFS=':' read -r instance drift_count; do
              send_notification "ALERT: Configuration drift detected on $instance" "WARNING"
              
              # Create new baseline if self-healing is enabled
              if [ "$SELF_HEALING" = "true" ]; then
                execute_action "config-reset" "Reset configuration baseline on $instance" "
                  systemctl start ai-config-baseline || true
                "
              else
                send_notification "INFO: Configuration drift on $instance - self-healing disabled" "INFO"
              fi
            done <<< "$config_drift"
          fi
          ''}
          
          # 5. Check AI provider health
          echo "[$(date)] Checking AI provider health..."
          
          # Check if AI providers are responding
          if command -v ai-cli &> /dev/null; then
            for provider in anthropic openai gemini ollama; do
              if ! timeout 30 ai-cli -p "$provider" "test" &>/dev/null; then
                send_notification "WARNING: AI provider $provider not responding" "WARNING"
                
                # Attempt to restart related services
                if [ "$provider" = "ollama" ] && [ "$SELF_HEALING" = "true" ]; then
                  execute_action "service-restart" "Restart Ollama service" "systemctl restart ollama"
                fi
              fi
            done
          fi
          
          # 6. Check system load and performance
          echo "[$(date)] Checking system performance..."
          
          # Query system load from Prometheus
          high_load=$(query_prometheus 'node_load1 > 8' | head -10)
          
          if [ -n "$high_load" ]; then
            while IFS=':' read -r instance load; do
              send_notification "ALERT: High system load $load on $instance" "WARNING"
              
              # Attempt load reduction if self-healing is enabled
              if [ "$SELF_HEALING" = "true" ]; then
                execute_action "load-reduction" "Reduce system load on $instance" "
                  # Kill any runaway nix-build processes
                  pkill -f nix-build || true
                  
                  # Restart high-CPU services
                  systemctl restart grafana || true
                  
                  # Reduce CPU frequency if available
                  if command -v cpupower &> /dev/null; then
                    cpupower frequency-set -g powersave || true
                  fi
                "
              fi
            done <<< "$high_load"
          fi
          
          # 7. Generate remediation report
          echo "[$(date)] Generating remediation report..."
          
          cat > /var/lib/ai-analysis/remediation-report.json << EOF
          {
            "timestamp": "$(date -Iseconds)",
            "hostname": "$(hostname)",
            "safe_mode": $SAFE_MODE,
            "self_healing": $SELF_HEALING,
            "actions_enabled": {
              "disk_cleanup": ${if cfg.actions.diskCleanup then "true" else "false"},
              "memory_optimization": ${if cfg.actions.memoryOptimization then "true" else "false"},
              "service_restart": ${if cfg.actions.serviceRestart then "true" else "false"},
              "configuration_reset": ${if cfg.actions.configurationReset then "true" else "false"}
            },
            "last_run": "$(date -Iseconds)",
            "status": "completed"
          }
          EOF
          
          echo "[$(date)] Automated remediation cycle completed"
        '';
      };
    };

    # Timer for regular remediation checks
    systemd.timers.ai-automated-remediation = {
      description = "AI Automated Remediation Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/15"; # Every 15 minutes
        Persistent = true;
        RandomizedDelaySec = "2m";
      };
    };

    # Emergency remediation service (triggered by critical alerts)
    systemd.services.ai-emergency-remediation = {
      description = "AI Emergency Remediation Service";
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "ai-emergency-remediation" ''
          #!/bin/bash
          
          LOG_FILE="${cfg.notifications.logFile}"
          mkdir -p "$(dirname "$LOG_FILE")"
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1
          
          echo "[$(date)] EMERGENCY: Starting emergency remediation..."
          
          # Emergency disk cleanup
          echo "[$(date)] Emergency disk cleanup..."
          nix-collect-garbage -d --delete-older-than 1h
          nix-store --optimise
          
          # Emergency memory cleanup
          echo "[$(date)] Emergency memory cleanup..."
          echo 3 > /proc/sys/vm/drop_caches
          sync
          
          # Emergency service cleanup
          echo "[$(date)] Emergency service cleanup..."
          systemctl restart grafana || true
          systemctl restart prometheus || true
          systemctl restart chromadb || true
          
          # Emergency Docker cleanup
          if command -v docker &> /dev/null; then
            docker system prune -af --volumes || true
          fi
          
          echo "[$(date)] Emergency remediation completed"
        '';
      };
    };

    # Create directories for logging and reports
    systemd.tmpfiles.rules = [
      "d /var/log/ai-analysis 0755 ai-analysis ai-analysis -"
      "d /var/lib/ai-analysis 0755 ai-analysis ai-analysis -"
    ];

    # Enhanced log rotation for remediation logs
    services.logrotate.settings = mkIf cfg.notifications.enable {
      "${cfg.notifications.logFile}" = {
        frequency = "daily";
        rotate = 30;
        compress = true;
        delaycompress = true;
        missingok = true;
        notifempty = true;
        create = "0644 ai-analysis ai-analysis";
      };
    };

    # Security considerations for automated remediation
    security.sudo.extraRules = [
      {
        users = [ "ai-analysis" ];
        commands = [
          {
            command = "/run/current-system/sw/bin/systemctl restart grafana";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl restart prometheus";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/systemctl restart chromadb";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/nix-collect-garbage";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/nix-store";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}