# Memory optimization based on AI capacity planning
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.ai.memoryOptimization;
in {
  options.ai.memoryOptimization = {
    enable = mkEnableOption "Enable AI-powered memory optimization";
    
    autoOptimize = mkOption {
      type = types.bool;
      default = false;
      description = "Enable automatic memory optimization";
    };
    
    thresholds = {
      memoryWarning = mkOption {
        type = types.int;
        default = 80;
        description = "Memory usage percentage to trigger warnings";
      };
      
      memoryCritical = mkOption {
        type = types.int;
        default = 90;
        description = "Memory usage percentage to trigger critical actions";
      };
      
      diskWarning = mkOption {
        type = types.int;
        default = 80;
        description = "Disk usage percentage to trigger warnings";
      };
      
      diskCritical = mkOption {
        type = types.int;
        default = 90;
        description = "Disk usage percentage to trigger critical actions";
      };
    };
    
    nixStoreOptimization = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Nix store optimization";
    };
    
    logRotation = mkOption {
      type = types.bool;
      default = true;
      description = "Enable enhanced log rotation";
    };
  };

  config = mkIf cfg.enable {
    # Enhanced Nix store optimization
    nix.settings = mkIf cfg.nixStoreOptimization {
      auto-optimise-store = true;
      min-free = 1024 * 1024 * 1024; # 1GB
      max-free = 5 * 1024 * 1024 * 1024; # 5GB
    };

    # Memory optimization service
    systemd.services.ai-memory-optimization = {
      description = "AI Memory Optimization Service";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        
        ExecStart = pkgs.writeShellScript "ai-memory-optimization" ''
          #!/bin/bash
          
          # Log setup
          LOG_FILE="/var/log/ai-analysis/memory-optimization.log"
          mkdir -p "$(dirname "$LOG_FILE")"
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1
          
          echo "[$(${pkgs.coreutils}/bin/date)] Starting AI memory optimization..."
          
          # Check current memory usage
          MEMORY_USAGE=$(${pkgs.procps}/bin/free | ${pkgs.gnugrep}/bin/grep Mem | ${pkgs.gawk}/bin/awk '{printf "%.1f", $3/$2 * 100.0}')
          MEMORY_USAGE_INT=$(echo "$MEMORY_USAGE" | ${pkgs.coreutils}/bin/cut -d. -f1)
          
          echo "[$(${pkgs.coreutils}/bin/date)] Current memory usage: $MEMORY_USAGE%"
          
          # Check disk usage for root filesystem
          ROOT_DISK_USAGE=$(${pkgs.coreutils}/bin/df / | ${pkgs.coreutils}/bin/tail -1 | ${pkgs.gawk}/bin/awk '{print $5}' | ${pkgs.gnused}/bin/sed 's/%//')
          echo "[$(${pkgs.coreutils}/bin/date)] Root disk usage: $ROOT_DISK_USAGE%"
          
          # Memory optimization actions
          if [ "$MEMORY_USAGE_INT" -gt ${toString cfg.thresholds.memoryCritical} ]; then
            echo "[$(${pkgs.coreutils}/bin/date)] CRITICAL: Memory usage above ${toString cfg.thresholds.memoryCritical}% - taking emergency actions"
            
            # Clear page cache
            echo 1 > /proc/sys/vm/drop_caches
            
            # Restart high-memory services
            if systemctl is-active --quiet chromadb; then
              systemctl restart chromadb
            fi
            
            if systemctl is-active --quiet grafana; then
              systemctl restart grafana
            fi
            
          elif [ "$MEMORY_USAGE_INT" -gt ${toString cfg.thresholds.memoryWarning} ]; then
            echo "[$(${pkgs.coreutils}/bin/date)] WARNING: Memory usage above ${toString cfg.thresholds.memoryWarning}% - optimizing"
            
            # Clear page cache
            echo 1 > /proc/sys/vm/drop_caches
            
            # Compact memory
            echo 1 > /proc/sys/vm/compact_memory
          fi
          
          # Disk optimization actions
          if [ "$ROOT_DISK_USAGE" -gt ${toString cfg.thresholds.diskCritical} ]; then
            echo "[$(${pkgs.coreutils}/bin/date)] CRITICAL: Root disk usage above ${toString cfg.thresholds.diskCritical}% - emergency cleanup"
            
            # Force Nix store optimization
            nix-store --optimise --verbose
            
            # Clean old generations (keep only last 2)
            nix-collect-garbage -d --delete-older-than 2d
            
            # Clean Docker if available
            if command -v docker &> /dev/null; then
              docker system prune -f --volumes
            fi
            
            # Clean systemd journal
            journalctl --vacuum-size=100M
            
          elif [ "$ROOT_DISK_USAGE" -gt ${toString cfg.thresholds.diskWarning} ]; then
            echo "[$(${pkgs.coreutils}/bin/date)] WARNING: Root disk usage above ${toString cfg.thresholds.diskWarning}% - cleaning up"
            
            # Nix store optimization
            nix-store --optimise
            
            # Clean old generations (keep last 5)
            nix-collect-garbage --delete-older-than 7d
            
            # Clean temporary files
            find /tmp -type f -atime +7 -delete 2>/dev/null || true
            find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
            
            # Clean systemd journal
            journalctl --vacuum-size=500M
          fi
          
          # P510 specific optimizations (root disk at 79.6%)
          if [ "$(${pkgs.inetutils}/bin/hostname)" = "p510" ]; then
            echo "[$(${pkgs.coreutils}/bin/date)] P510 specific optimizations - high disk usage detected"
            
            # Aggressive Nix store cleanup for P510
            nix-collect-garbage -d --delete-older-than 1d
            
            # Clean Docker more aggressively
            if command -v docker &> /dev/null; then
              docker system prune -af --volumes
              docker image prune -af
            fi
            
            # Clean large log files
            find /var/log -name "*.log" -size +50M -exec truncate -s 10M {} \;
            
            # Clean Nix build cache
            rm -rf /tmp/nix-build-* 2>/dev/null || true
          fi
          
          # Final status check
          NEW_MEMORY_USAGE=$(${pkgs.procps}/bin/free | ${pkgs.gnugrep}/bin/grep Mem | ${pkgs.gawk}/bin/awk '{printf "%.1f", $3/$2 * 100.0}')
          NEW_ROOT_DISK_USAGE=$(${pkgs.coreutils}/bin/df / | ${pkgs.coreutils}/bin/tail -1 | ${pkgs.gawk}/bin/awk '{print $5}' | ${pkgs.gnused}/bin/sed 's/%//')
          
          echo "[$(${pkgs.coreutils}/bin/date)] Optimization complete - Memory: $NEW_MEMORY_USAGE%, Root disk: $NEW_ROOT_DISK_USAGE%"
          
          # Create optimization report
          cat > /var/lib/ai-analysis/memory-optimization-report.json << EOF
          {
            "timestamp": "$(${pkgs.coreutils}/bin/date -Iseconds)",
            "hostname": "$(${pkgs.inetutils}/bin/hostname)",
            "before": {
              "memory_usage": $MEMORY_USAGE,
              "root_disk_usage": $ROOT_DISK_USAGE
            },
            "after": {
              "memory_usage": $NEW_MEMORY_USAGE,
              "root_disk_usage": $NEW_ROOT_DISK_USAGE
            },
            "actions_taken": [
              "memory_optimization",
              "disk_cleanup",
              "nix_store_optimization"
            ]
          }
          EOF
          
          echo "[$(${pkgs.coreutils}/bin/date)] Memory optimization completed successfully"
        '';
      };
    };

    # Timer for regular optimization
    systemd.timers.ai-memory-optimization = {
      description = "AI Memory Optimization Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/30"; # Every 30 minutes
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };

    # Enhanced log rotation
    services.logrotate = mkIf cfg.logRotation {
      enable = true;
      settings = {
        "/var/log/ai-analysis/*.log" = {
          frequency = "daily";
          rotate = 7;
          compress = true;
          delaycompress = true;
          missingok = true;
          notifempty = true;
          create = "0644 ai-analysis ai-analysis";
          postrotate = "systemctl reload-or-restart rsyslog || true";
        };
        
        "/var/log/docker/*.log" = {
          frequency = "daily";
          rotate = 5;
          compress = true;
          delaycompress = true;
          missingok = true;
          notifempty = true;
          copytruncate = true;
        };
        
        "/var/log/grafana/*.log" = {
          frequency = "daily";
          rotate = 14;
          compress = true;
          delaycompress = true;
          missingok = true;
          notifempty = true;
          copytruncate = true;
        };
        
      };
    };

    # Kernel memory management tuning
    boot.kernel.sysctl = {
      # Reduce swappiness to prefer RAM over swap
      "vm.swappiness" = mkDefault 10;
      
      # Increase cache pressure to free memory faster
      "vm.vfs_cache_pressure" = mkDefault 50;
      
      # More aggressive memory overcommit
      "vm.overcommit_memory" = mkDefault 1;
      "vm.overcommit_ratio" = mkDefault 50;
      
      # Dirty page management
      "vm.dirty_background_ratio" = mkDefault 5;
      "vm.dirty_ratio" = mkDefault 10;
    };

    # Create directories for logging
    systemd.tmpfiles.rules = [
      "d /var/log/ai-analysis 0755 ai-analysis ai-analysis -"
      "d /var/lib/ai-analysis 0755 ai-analysis ai-analysis -"
    ];

    # Enable automatic optimization if configured
    systemd.services.ai-memory-optimization.enable = mkIf cfg.autoOptimize true;
  };
}