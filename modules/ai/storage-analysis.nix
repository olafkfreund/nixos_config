# P510 Storage Analysis and Emergency Cleanup System
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.ai.storageAnalysis;
in {
  options.ai.storageAnalysis = {
    enable = mkEnableOption "Enable AI-powered storage analysis";
    
    emergencyMode = mkOption {
      type = types.bool;
      default = false;
      description = "Enable emergency cleanup mode for critical storage situations";
    };
    
    analysisInterval = mkOption {
      type = types.str;
      default = "hourly";
      description = "How often to run storage analysis";
    };
    
    reportPath = mkOption {
      type = types.str;
      default = "/var/lib/ai-analysis/storage-reports";
      description = "Path to store analysis reports";
    };
  };

  config = mkIf cfg.enable {
    # Storage analysis service
    systemd.services.ai-storage-analysis = {
      description = "AI Storage Analysis Service";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "ai-storage-analysis" ''
          #!/bin/bash
          
          # Configuration
          REPORT_DIR="${cfg.reportPath}"
          EMERGENCY_MODE="${if cfg.emergencyMode then "true" else "false"}"
          HOSTNAME=$(hostname)
          TIMESTAMP=$(date +%Y%m%d_%H%M%S)
          REPORT_FILE="$REPORT_DIR/storage_analysis_$HOSTNAME_$TIMESTAMP.json"
          LOG_FILE="/var/log/ai-analysis/storage-analysis.log"
          
          # Ensure directories exist
          mkdir -p "$REPORT_DIR"
          mkdir -p "$(dirname "$LOG_FILE")"
          
          # Setup logging
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1
          
          echo "[$(date)] Starting storage analysis on $HOSTNAME..."
          echo "[$(date)] Emergency mode: $EMERGENCY_MODE"
          
          # Function to get directory size efficiently
          get_dir_size() {
            local dir="$1"
            if [ -d "$dir" ]; then
              du -sb "$dir" 2>/dev/null | cut -f1 || echo "0"
            else
              echo "0"
            fi
          }
          
          # Function to convert bytes to human readable
          human_readable() {
            local bytes="$1"
            if command -v numfmt &>/dev/null; then
              numfmt --to=iec-i --suffix=B "$bytes" 2>/dev/null || echo "$bytes bytes"
            else
              echo "$bytes bytes"
            fi
          }
          
          # Collect basic disk information
          echo "[$(date)] Collecting disk usage information..."
          
          # Get filesystem information
          DISK_INFO=$(df -B1 --output=source,size,used,avail,pcent,target | tail -n +2)
          
          # Analyze Nix store
          echo "[$(date)] Analyzing Nix store..."
          NIX_STORE_SIZE=$(get_dir_size /nix/store)
          NIX_STORE_HUMAN=$(human_readable $NIX_STORE_SIZE)
          
          # Count Nix generations
          NIX_GENERATIONS=$(nix-env --list-generations | wc -l)
          SYSTEM_GENERATIONS=$(ls -1 /nix/var/nix/profiles/system-*-link 2>/dev/null | wc -l)
          
          # Analyze large directories
          echo "[$(date)] Finding largest directories..."
          LARGE_DIRS=$(find / -maxdepth 3 -type d \
            -not -path "/proc/*" \
            -not -path "/sys/*" \
            -not -path "/dev/*" \
            -not -path "/run/*" \
            -not -path "/tmp/*" \
            -not -path "/nix/store/*" \
            2>/dev/null | \
            xargs -I {} sh -c 'size=$(du -sb "{}" 2>/dev/null | cut -f1); [ "$size" -gt 1073741824 ] && echo "$size:{}"' | \
            sort -nr | head -20)
          
          # Analyze logs
          echo "[$(date)] Analyzing log files..."
          LOG_SIZES=$(find /var/log -type f -name "*.log" -o -name "*.log.*" 2>/dev/null | \
            xargs -I {} sh -c 'size=$(stat -f%z "{}" 2>/dev/null || stat -c%s "{}" 2>/dev/null || echo 0); echo "$size:{}"' | \
            sort -nr | head -10)
          
          # Analyze Docker if present
          DOCKER_INFO=""
          if command -v docker &>/dev/null && systemctl is-active docker &>/dev/null; then
            echo "[$(date)] Analyzing Docker storage..."
            DOCKER_INFO=$(docker system df --format "table {{.Type}}\t{{.Total}}\t{{.Active}}\t{{.Size}}\t{{.Reclaimable}}" 2>/dev/null || echo "Docker analysis failed")
          fi
          
          # Check for core dumps and crash files
          echo "[$(date)] Checking for crash files..."
          CRASH_FILES=$(find /var/crash /var/lib/systemd/coredump /tmp -name "core.*" -o -name "*.core" -o -name "crash.*" 2>/dev/null | \
            xargs -I {} sh -c 'size=$(stat -f%z "{}" 2>/dev/null || stat -c%s "{}" 2>/dev/null || echo 0); echo "$size:{}"' | \
            sort -nr | head -10)
          
          # Check package cache
          echo "[$(date)] Analyzing package caches..."
          PACKAGE_CACHE_SIZE=0
          if [ -d /var/cache ]; then
            PACKAGE_CACHE_SIZE=$(get_dir_size /var/cache)
          fi
          
          # Check for old kernels (if applicable)
          KERNEL_INFO=""
          if [ -d /boot ]; then
            KERNEL_COUNT=$(ls -1 /boot/vmlinuz-* 2>/dev/null | wc -l)
            KERNEL_INFO="$KERNEL_COUNT kernels found"
          fi
          
          # Calculate cleanup potential
          echo "[$(date)] Calculating cleanup potential..."
          
          # Estimate Nix cleanup potential
          OLD_GENERATIONS_SIZE=0
          if [ "$NIX_GENERATIONS" -gt 5 ]; then
            # Rough estimate: each generation ~1-2GB
            OLD_GENERATIONS_SIZE=$((($NIX_GENERATIONS - 5) * 1500000000))
          fi
          
          # Generate comprehensive report
          cat > "$REPORT_FILE" << EOF
          {
            "analysis_metadata": {
              "hostname": "$HOSTNAME",
              "timestamp": "$(date -Iseconds)",
              "emergency_mode": $EMERGENCY_MODE,
              "analyzer_version": "1.0"
            },
            "disk_usage": {
              "filesystem_info": [
          $(echo "$DISK_INFO" | while IFS=' ' read -r source size used avail pcent target; do
            [ -n "$source" ] && cat << INNER_EOF
                {
                  "device": "$source",
                  "total_bytes": $size,
                  "used_bytes": $used,
                  "available_bytes": $avail,
                  "usage_percent": "${pcent%\%}",
                  "mount_point": "$target",
                  "total_human": "$(human_readable $size)",
                  "used_human": "$(human_readable $used)",
                  "available_human": "$(human_readable $avail)"
                },
          INNER_EOF
          done | sed '$ s/,$//')
              ]
            },
            "nix_analysis": {
              "store_size_bytes": $NIX_STORE_SIZE,
              "store_size_human": "$NIX_STORE_HUMAN",
              "user_generations": $NIX_GENERATIONS,
              "system_generations": $SYSTEM_GENERATIONS,
              "estimated_cleanup_bytes": $OLD_GENERATIONS_SIZE,
              "estimated_cleanup_human": "$(human_readable $OLD_GENERATIONS_SIZE)"
            },
            "large_directories": [
          $(echo "$LARGE_DIRS" | while IFS=':' read -r size path; do
            [ -n "$size" ] && [ -n "$path" ] && cat << INNER_EOF
              {
                "path": "$path",
                "size_bytes": $size,
                "size_human": "$(human_readable $size)"
              },
          INNER_EOF
          done | sed '$ s/,$//')
            ],
            "log_analysis": {
              "package_cache_bytes": $PACKAGE_CACHE_SIZE,
              "package_cache_human": "$(human_readable $PACKAGE_CACHE_SIZE)",
              "large_logs": [
          $(echo "$LOG_SIZES" | while IFS=':' read -r size path; do
            [ -n "$size" ] && [ -n "$path" ] && cat << INNER_EOF
                {
                  "path": "$path",
                  "size_bytes": $size,
                  "size_human": "$(human_readable $size)"
                },
          INNER_EOF
          done | sed '$ s/,$//')
              ]
            },
            "crash_files": [
          $(echo "$CRASH_FILES" | while IFS=':' read -r size path; do
            [ -n "$size" ] && [ -n "$path" ] && cat << INNER_EOF
              {
                "path": "$path",
                "size_bytes": $size,
                "size_human": "$(human_readable $size)"
              },
          INNER_EOF
          done | sed '$ s/,$//')
            ],
            "docker_analysis": "$DOCKER_INFO",
            "kernel_info": "$KERNEL_INFO",
            "cleanup_recommendations": {
              "immediate_actions": [
                "nix-collect-garbage -d --delete-older-than 7d",
                "nix-store --optimise",
                "journalctl --vacuum-size=100M",
                "find /tmp -atime +7 -delete",
                "docker system prune -af (if Docker is used)"
              ],
              "potential_space_recovery_bytes": $(($OLD_GENERATIONS_SIZE + $PACKAGE_CACHE_SIZE)),
              "potential_space_recovery_human": "$(human_readable $(($OLD_GENERATIONS_SIZE + $PACKAGE_CACHE_SIZE)))"
            }
          }
          EOF
          
          echo "[$(date)] Storage analysis complete. Report saved to: $REPORT_FILE"
          
          # If emergency mode, execute immediate cleanup
          if [ "$EMERGENCY_MODE" = "true" ]; then
            echo "[$(date)] EMERGENCY MODE: Executing immediate cleanup actions..."
            
            # Create backup of critical configs before cleanup
            backup_dir="/var/backups/emergency-cleanup-$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$backup_dir"
            
            # Backup critical configurations
            cp -r /etc/nixos "$backup_dir/" 2>/dev/null || true
            cp /etc/machine-id "$backup_dir/" 2>/dev/null || true
            
            echo "[$(date)] Backup created at: $backup_dir"
            
            # Execute cleanup actions
            echo "[$(date)] Cleaning old Nix generations..."
            nix-collect-garbage -d --delete-older-than 1d
            
            echo "[$(date)] Optimizing Nix store..."
            nix-store --optimise
            
            echo "[$(date)] Cleaning system logs..."
            journalctl --vacuum-size=50M
            
            echo "[$(date)] Cleaning temporary files..."
            find /tmp -type f -atime +1 -delete 2>/dev/null || true
            find /var/tmp -type f -atime +1 -delete 2>/dev/null || true
            
            # Clean package caches
            echo "[$(date)] Cleaning package caches..."
            rm -rf /var/cache/fontconfig/* 2>/dev/null || true
            rm -rf /var/cache/man/* 2>/dev/null || true
            
            # Clean Docker if present and safe
            if command -v docker &>/dev/null && systemctl is-active docker &>/dev/null; then
              echo "[$(date)] Cleaning Docker system..."
              docker system prune -f --volumes 2>/dev/null || true
            fi
            
            # Remove crash dumps
            echo "[$(date)] Removing crash dumps..."
            find /var/crash /var/lib/systemd/coredump -name "core.*" -delete 2>/dev/null || true
            
            echo "[$(date)] Emergency cleanup completed!"
            
            # Generate post-cleanup report
            NEW_DISK_INFO=$(df -B1 --output=source,size,used,avail,pcent,target | tail -n +2)
            echo "[$(date)] Post-cleanup disk usage:"
            df -h
          fi
          
          echo "[$(date)] Storage analysis service completed successfully"
        '';
      };
    };

    # Timer for regular analysis
    systemd.timers.ai-storage-analysis = {
      description = "AI Storage Analysis Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.analysisInterval;
        Persistent = true;
        RandomizedDelaySec = "10m";
      };
    };

    # Emergency cleanup service
    systemd.services.ai-emergency-storage-cleanup = {
      description = "AI Emergency Storage Cleanup";
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "ai-emergency-cleanup" ''
          #!/bin/bash
          
          LOG_FILE="/var/log/ai-analysis/emergency-cleanup.log"
          mkdir -p "$(dirname "$LOG_FILE")"
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1
          
          echo "[$(date)] EMERGENCY: Starting critical storage cleanup..."
          
          # Check current disk usage
          ROOT_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
          echo "[$(date)] Current root filesystem usage: $ROOT_USAGE%"
          
          if [ "$ROOT_USAGE" -gt 85 ]; then
            echo "[$(date)] CRITICAL: Executing emergency cleanup procedures..."
            
            # Ultra-aggressive Nix cleanup
            nix-collect-garbage -d --delete-older-than 6h
            nix-store --optimise
            
            # Emergency log cleanup
            journalctl --vacuum-size=10M
            find /var/log -name "*.log" -size +10M -exec truncate -s 5M {} \;
            
            # Emergency temp cleanup
            find /tmp -type f -mmin +60 -delete 2>/dev/null || true
            find /var/tmp -type f -mmin +60 -delete 2>/dev/null || true
            
            # Emergency Docker cleanup
            if command -v docker &>/dev/null; then
              docker system prune -af --volumes 2>/dev/null || true
              docker image prune -af 2>/dev/null || true
            fi
            
            # Clear all caches
            rm -rf /var/cache/* 2>/dev/null || true
            echo 3 > /proc/sys/vm/drop_caches
            
            NEW_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
            echo "[$(date)] Post-cleanup root filesystem usage: $NEW_USAGE%"
            echo "[$(date)] Space recovered: $(($ROOT_USAGE - $NEW_USAGE))%"
          else
            echo "[$(date)] Root filesystem usage is acceptable ($ROOT_USAGE%), no emergency action needed"
          fi
          
          echo "[$(date)] Emergency cleanup completed"
        '';
      };
    };

    # Create directories for reports and logs
    systemd.tmpfiles.rules = [
      "d ${cfg.reportPath} 0755 ai-analysis ai-analysis -"
      "d /var/log/ai-analysis 0755 ai-analysis ai-analysis -"
      "d /var/backups 0755 root root -"
    ];
  };
}