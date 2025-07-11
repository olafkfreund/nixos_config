# AI System Performance Optimization Module
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.ai.performanceOptimization;
in {
  options.ai.performanceOptimization = {
    enable = mkEnableOption "Enable AI system performance optimization";
    
    aiProviderOptimization = mkOption {
      type = types.bool;
      default = true;
      description = "Enable AI provider response optimization";
    };
    
    cacheOptimization = mkOption {
      type = types.bool;
      default = true;
      description = "Enable intelligent caching optimization";
    };
    
    networkOptimization = mkOption {
      type = types.bool;
      default = true;
      description = "Enable network performance optimization";
    };
    
    systemOptimization = mkOption {
      type = types.bool;
      default = true;
      description = "Enable system-level performance optimization";
    };
  };

  config = mkIf cfg.enable {
    # AI Provider Performance Optimization Service
    systemd.services.ai-provider-optimization = {
      description = "AI Provider Performance Optimization";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "ai-provider-optimization" ''
          #!/bin/bash
          
          LOG_FILE="/var/log/ai-analysis/performance-optimization.log"
          ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$LOG_FILE")"
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1
          
          echo "[$(${pkgs.coreutils}/bin/date)] Starting AI provider performance optimization..."
          
          # Configure AI provider timeouts and connection pooling
          if [ -f /etc/ai-providers.json ]; then
            echo "[$(${pkgs.coreutils}/bin/date)] Optimizing AI provider configuration..."
            
            # Create optimized AI provider configuration
            ${pkgs.coreutils}/bin/cat > /etc/ai-providers.json.optimized << 'EOF'
          {
            "providers": {
              "anthropic": {
                "priority": 2,
                "model": "claude-3-5-sonnet-20241022",
                "timeout": 30,
                "max_retries": 3,
                "retry_delay": 1,
                "connection_pool_size": 10,
                "keep_alive": true,
                "compression": true
              },
              "openai": {
                "priority": 1,
                "model": "gpt-4o-mini",
                "timeout": 25,
                "max_retries": 2,
                "retry_delay": 2,
                "connection_pool_size": 8,
                "keep_alive": true,
                "compression": true
              },
              "gemini": {
                "priority": 3,
                "model": "gemini-1.5-flash",
                "timeout": 20,
                "max_retries": 2,
                "retry_delay": 1,
                "connection_pool_size": 5,
                "keep_alive": true,
                "compression": true
              },
              "ollama": {
                "priority": 4,
                "model": "mistral-small3.1",
                "timeout": 15,
                "max_retries": 1,
                "retry_delay": 0,
                "connection_pool_size": 3,
                "keep_alive": true,
                "local": true
              }
            },
            "global_settings": {
              "default_timeout": 30,
              "max_concurrent_requests": 10,
              "enable_caching": true,
              "cache_ttl": 3600,
              "enable_compression": true,
              "connection_timeout": 10,
              "read_timeout": 30,
              "enable_keepalive": true,
              "keepalive_timeout": 60
            }
          }
          EOF
            
            # Backup original and replace with optimized version
            ${pkgs.coreutils}/bin/cp /etc/ai-providers.json /etc/ai-providers.json.backup
            ${pkgs.coreutils}/bin/mv /etc/ai-providers.json.optimized /etc/ai-providers.json
            
            echo "[$(${pkgs.coreutils}/bin/date)] AI provider configuration optimized"
          fi
          
          # Configure AI CLI performance settings
          if ${pkgs.coreutils}/bin/command -v ai-cli &>/dev/null; then
            echo "[$(${pkgs.coreutils}/bin/date)] Optimizing AI CLI performance..."
            
            # Set environment variables for better performance
            export AI_TIMEOUT=30
            export AI_MAX_RETRIES=3
            export AI_RETRY_DELAY=1
            export AI_ENABLE_CACHE=true
            export AI_CACHE_TTL=3600
            export AI_COMPRESSION=true
            
            # Test AI provider performance
            echo "[$(${pkgs.coreutils}/bin/date)] Testing AI provider performance..."
            
            for provider in anthropic openai gemini ollama; do
              echo "[$(${pkgs.coreutils}/bin/date)] Testing $provider..."
              start_time=$(${pkgs.coreutils}/bin/date +%s%3N)
              
              if ${pkgs.coreutils}/bin/timeout 30 ai-cli -p "$provider" "test response time" &>/dev/null; then
                end_time=$(${pkgs.coreutils}/bin/date +%s%3N)
                response_time=$((end_time - start_time))
                echo "[$(${pkgs.coreutils}/bin/date)] $provider response time: ''${response_time}ms"
                
                # Log performance metrics
                echo "$(${pkgs.coreutils}/bin/date -Iseconds),$provider,$response_time,success" >> /var/lib/ai-analysis/provider-performance.csv
              else
                echo "[$(${pkgs.coreutils}/bin/date)] $provider timeout or error"
                echo "$(${pkgs.coreutils}/bin/date -Iseconds),$provider,30000,timeout" >> /var/lib/ai-analysis/provider-performance.csv
              fi
            done
          fi
          
          echo "[$(${pkgs.coreutils}/bin/date)] AI provider optimization completed"
        '';
      };
    };

    # System Performance Optimization Service
    systemd.services.ai-system-optimization = mkIf cfg.systemOptimization {
      description = "AI System Performance Optimization";
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "ai-system-optimization" ''
          #!/bin/bash
          
          LOG_FILE="/var/log/ai-analysis/system-optimization.log"
          ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$LOG_FILE")"
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1
          
          echo "[$(${pkgs.coreutils}/bin/date)] Starting system performance optimization..."
          
          # CPU scheduling optimization for AI workloads
          echo "[$(${pkgs.coreutils}/bin/date)] Optimizing CPU scheduling..."
          
          # Set CPU governor to performance for AI processes
          if [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; then
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
              if [ -w "$cpu" ]; then
                echo "performance" > "$cpu" 2>/dev/null || true
              fi
            done
            echo "[$(${pkgs.coreutils}/bin/date)] CPU governor set to performance"
          fi
          
          # I/O scheduling optimization
          echo "[$(${pkgs.coreutils}/bin/date)] Optimizing I/O scheduling..."
          
          # Set I/O scheduler to deadline for better AI workload performance
          for device in /sys/block/*/queue/scheduler; do
            if [ -w "$device" ]; then
              echo "deadline" > "$device" 2>/dev/null || true
            fi
          done
          
          # Memory optimization for AI workloads
          echo "[$(${pkgs.coreutils}/bin/date)] Optimizing memory management..."
          
          # Adjust swappiness for AI workloads
          echo 10 > /proc/sys/vm/swappiness
          
          # Optimize dirty page handling
          echo 15 > /proc/sys/vm/dirty_background_ratio
          echo 30 > /proc/sys/vm/dirty_ratio
          
          # Optimize cache pressure
          echo 50 > /proc/sys/vm/vfs_cache_pressure
          
          # Network optimization for AI providers
          echo "[$(${pkgs.coreutils}/bin/date)] Optimizing network performance..."
          
          # TCP optimization for AI API calls
          echo 1 > /proc/sys/net/ipv4/tcp_window_scaling
          echo 1 > /proc/sys/net/ipv4/tcp_timestamps
          echo 1 > /proc/sys/net/ipv4/tcp_sack
          echo 1 > /proc/sys/net/ipv4/tcp_fack
          
          # Increase TCP buffer sizes for better throughput
          echo "4096 65536 16777216" > /proc/sys/net/ipv4/tcp_rmem
          echo "4096 65536 16777216" > /proc/sys/net/ipv4/tcp_wmem
          
          # Optimize connection handling
          echo 65536 > /proc/sys/net/core/rmem_max
          echo 65536 > /proc/sys/net/core/wmem_max
          echo 1024 > /proc/sys/net/core/netdev_max_backlog
          
          echo "[$(${pkgs.coreutils}/bin/date)] System optimization completed"
        '';
      };
    };

    # Cache Optimization Service
    systemd.services.ai-cache-optimization = mkIf cfg.cacheOptimization {
      description = "AI Cache Optimization";
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "ai-cache-optimization" ''
          #!/bin/bash
          
          LOG_FILE="/var/log/ai-analysis/cache-optimization.log"
          ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$LOG_FILE")"
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1
          
          echo "[$(${pkgs.coreutils}/bin/date)] Starting cache optimization..."
          
          # Create AI response cache directory
          ${pkgs.coreutils}/bin/mkdir -p /var/cache/ai-analysis
          ${pkgs.coreutils}/bin/chmod 755 /var/cache/ai-analysis
          
          # Redis-like caching for AI responses (simple file-based)
          ${pkgs.coreutils}/bin/cat > /usr/local/bin/ai-cache-manager << 'EOF'
          #!/bin/bash
          
          CACHE_DIR="/var/cache/ai-analysis"
          CACHE_TTL=3600  # 1 hour
          
          cache_get() {
            local key="$1"
            local cache_file="$CACHE_DIR/$(echo "$key" | sha256sum | cut -d' ' -f1)"
            
            if [ -f "$cache_file" ]; then
              local file_age=$(( $(date +%s) - $(stat -c %Y "$cache_file") ))
              if [ $file_age -lt $CACHE_TTL ]; then
                cat "$cache_file"
                return 0
              else
                rm -f "$cache_file"
              fi
            fi
            return 1
          }
          
          cache_set() {
            local key="$1"
            local value="$2"
            local cache_file="$CACHE_DIR/$(echo "$key" | sha256sum | cut -d' ' -f1)"
            
            echo "$value" > "$cache_file"
          }
          
          cache_cleanup() {
            find "$CACHE_DIR" -type f -mtime +1 -delete
          }
          
          case "$1" in
            get) cache_get "$2" ;;
            set) cache_set "$2" "$3" ;;
            cleanup) cache_cleanup ;;
            *) echo "Usage: $0 {get|set|cleanup}" ;;
          esac
          EOF
          
          ${pkgs.coreutils}/bin/chmod +x /usr/local/bin/ai-cache-manager
          
          # Set up cache cleanup cron job
          echo "0 * * * * root /usr/local/bin/ai-cache-manager cleanup" > /etc/cron.d/ai-cache-cleanup
          
          echo "[$(${pkgs.coreutils}/bin/date)] Cache optimization completed"
        '';
      };
    };

    # Performance monitoring service
    systemd.services.ai-performance-monitor = {
      description = "AI Performance Monitor";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "ai-performance-monitor" ''
          #!/bin/bash
          
          LOG_FILE="/var/log/ai-analysis/performance-monitor.log"
          METRICS_FILE="/var/lib/ai-analysis/performance-metrics.json"
          ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$LOG_FILE")"
          ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$METRICS_FILE")"
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1
          
          echo "[$(${pkgs.coreutils}/bin/date)] Starting performance monitoring..."
          
          # Collect system performance metrics
          TIMESTAMP=$(${pkgs.coreutils}/bin/date -Iseconds)
          HOSTNAME=$(${pkgs.nettools}/bin/hostname)
          
          # CPU metrics
          CPU_USAGE=$(${pkgs.procps}/bin/top -bn1 | ${pkgs.gnugrep}/bin/grep "Cpu(s)" | ${pkgs.gawk}/bin/awk '{print $2}' | ${pkgs.gnused}/bin/sed 's/%us,//' | ${pkgs.gnused}/bin/sed 's/,//')
          LOAD_AVG=$(${pkgs.procps}/bin/uptime | ${pkgs.gawk}/bin/awk -F'load average:' '{print $2}' | ${pkgs.gawk}/bin/awk '{print $1}' | ${pkgs.gnused}/bin/sed 's/,//')
          
          # Memory metrics
          MEMORY_TOTAL=$(${pkgs.procps}/bin/free -b | ${pkgs.gnugrep}/bin/grep Mem | ${pkgs.gawk}/bin/awk '{print $2}')
          MEMORY_USED=$(${pkgs.procps}/bin/free -b | ${pkgs.gnugrep}/bin/grep Mem | ${pkgs.gawk}/bin/awk '{print $3}')
          MEMORY_PERCENT=$(echo "scale=2; $MEMORY_USED * 100 / $MEMORY_TOTAL" | ${pkgs.bc}/bin/bc)
          
          # Disk metrics
          DISK_USAGE=$(${pkgs.coreutils}/bin/df / | ${pkgs.coreutils}/bin/tail -1 | ${pkgs.gawk}/bin/awk '{print $5}' | ${pkgs.gnused}/bin/sed 's/%//')
          
          # Network metrics
          if ${pkgs.coreutils}/bin/command -v ${pkgs.iproute2}/bin/ss &>/dev/null; then
            NETWORK_CONNECTIONS=$(${pkgs.iproute2}/bin/ss -tuln | ${pkgs.gnugrep}/bin/grep LISTEN | ${pkgs.coreutils}/bin/wc -l)
          else
            NETWORK_CONNECTIONS=0
          fi
          
          # AI service metrics
          AI_SERVICES_RUNNING=$(${pkgs.systemd}/bin/systemctl list-units --type=service --state=running | ${pkgs.gnugrep}/bin/grep -c ai- || echo 0)
          
          # Create performance metrics report
          cat > "$METRICS_FILE" << EOF
          {
            "timestamp": "$TIMESTAMP",
            "hostname": "$HOSTNAME",
            "system_metrics": {
              "cpu_usage_percent": "$CPU_USAGE",
              "load_average_1m": "$LOAD_AVG",
              "memory_total_bytes": $MEMORY_TOTAL,
              "memory_used_bytes": $MEMORY_USED,
              "memory_usage_percent": $MEMORY_PERCENT,
              "disk_usage_percent": $DISK_USAGE,
              "network_connections": $NETWORK_CONNECTIONS
            },
            "ai_metrics": {
              "ai_services_running": $AI_SERVICES_RUNNING,
              "ai_provider_status": "$(ai-cli --status 2>/dev/null | grep -c "✓" || echo 0)",
              "last_optimization": "$(${pkgs.coreutils}/bin/date -Iseconds)"
            }
          }
          EOF
          
          echo "[$(${pkgs.coreutils}/bin/date)] Performance metrics collected and saved to $METRICS_FILE"
        '';
      };
    };

    # Timers for regular optimization
    systemd.timers.ai-provider-optimization = {
      description = "AI Provider Optimization Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
        RandomizedDelaySec = "10m";
      };
    };

    systemd.timers.ai-system-optimization = mkIf cfg.systemOptimization {
      description = "AI System Optimization Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/30"; # Every 30 minutes
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };

    systemd.timers.ai-performance-monitor = {
      description = "AI Performance Monitor Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/15"; # Every 15 minutes
        Persistent = true;
        RandomizedDelaySec = "2m";
      };
    };

    # Create directories for optimization
    systemd.tmpfiles.rules = [
      "d /var/cache/ai-analysis 0755 root root -"
      "d /var/lib/ai-analysis 0755 ai-analysis ai-analysis -"
      "d /var/log/ai-analysis 0755 ai-analysis ai-analysis -"
    ];

    # Performance optimization kernel parameters
    boot.kernel.sysctl = mkIf cfg.systemOptimization {
      # Memory management optimization
      "vm.swappiness" = mkDefault 10;
      "vm.dirty_background_ratio" = mkDefault 15;
      "vm.dirty_ratio" = mkDefault 30;
      "vm.vfs_cache_pressure" = mkDefault 50;
      
      # Network optimization
      "net.ipv4.tcp_window_scaling" = 1;
      "net.ipv4.tcp_timestamps" = 1;
      "net.ipv4.tcp_sack" = 1;
      "net.ipv4.tcp_fack" = 1;
      "net.core.rmem_max" = 134217728;
      "net.core.wmem_max" = 134217728;
      "net.core.netdev_max_backlog" = 5000;
      
      # File system optimization
      "fs.file-max" = 2097152;
      "fs.inotify.max_user_watches" = 524288;
    };

    # Install performance monitoring tools
    environment.systemPackages = with pkgs; [
      htop
      iotop
      nethogs
      iftop
      sysstat
      bc
    ];
  };
}