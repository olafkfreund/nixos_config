# P510 Emergency Storage Migration Service
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.ai.storageMigration;
in {
  options.ai.storageMigration = {
    enable = mkEnableOption "Enable emergency storage migration for P510";
    
    targetVolume = mkOption {
      type = types.str;
      default = "/mnt/img_pool";
      description = "Target volume for migration (P510: img_pool has 938GB available)";
    };
    
    migrationMode = mkOption {
      type = types.enum [ "analysis" "preparation" "execution" ];
      default = "analysis";
      description = "Migration mode: analysis only, preparation, or full execution";
    };
  };

  config = mkIf cfg.enable {
    # Emergency storage migration service
    systemd.services.ai-emergency-migration = {
      description = "AI Emergency Storage Migration for P510";
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "ai-emergency-migration" ''
          #!/bin/bash
          
          # Configuration
          TARGET_VOLUME="${cfg.targetVolume}"
          MIGRATION_MODE="${cfg.migrationMode}"
          HOSTNAME=$(hostname)
          LOG_FILE="/var/log/ai-analysis/storage-migration.log"
          MIGRATION_PLAN="/var/lib/ai-analysis/migration-plan.json"
          
          # Ensure directories exist
          mkdir -p "$(dirname "$LOG_FILE")"
          mkdir -p "$(dirname "$MIGRATION_PLAN")"
          mkdir -p "$TARGET_VOLUME/migration-staging"
          
          # Setup logging
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1
          
          echo "[$(date)] Starting emergency storage migration for $HOSTNAME"
          echo "[$(date)] Target volume: $TARGET_VOLUME"
          echo "[$(date)] Migration mode: $MIGRATION_MODE"
          
          # Check if we're on P510 and in critical situation
          ROOT_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
          TARGET_AVAILABLE=$(df "$TARGET_VOLUME" | tail -1 | awk '{print $4}')
          TARGET_USAGE=$(df "$TARGET_VOLUME" | tail -1 | awk '{print $5}' | sed 's/%//')
          
          echo "[$(date)] Root filesystem usage: $ROOT_USAGE%"
          echo "[$(date)] Target volume usage: $TARGET_USAGE%"
          echo "[$(date)] Target available space: $(numfmt --to=iec-i --suffix=B $((TARGET_AVAILABLE * 1024)))"
          
          if [ "$ROOT_USAGE" -lt 75 ]; then
            echo "[$(date)] Root usage below 75%, migration not critical"
            if [ "$MIGRATION_MODE" != "analysis" ]; then
              echo "[$(date)] Switching to analysis mode"
              MIGRATION_MODE="analysis"
            fi
          fi
          
          # Analysis phase - identify migration candidates
          echo "[$(date)] === MIGRATION ANALYSIS ==="
          
          # Docker data analysis
          DOCKER_SIZE=0
          DOCKER_PATH=""
          if systemctl is-active docker &>/dev/null; then
            DOCKER_PATH="/var/lib/docker"
            if [ -d "$DOCKER_PATH" ]; then
              DOCKER_SIZE=$(du -sb "$DOCKER_PATH" 2>/dev/null | cut -f1 || echo "0")
              echo "[$(date)] Docker data: $(numfmt --to=iec-i --suffix=B $DOCKER_SIZE) at $DOCKER_PATH"
            fi
          fi
          
          # Large log directories
          LOG_DIRS=$(find /var/log -maxdepth 2 -type d 2>/dev/null | \
            xargs -I {} sh -c 'size=$(du -sb "{}" 2>/dev/null | cut -f1); [ "$size" -gt 104857600 ] && echo "$size:{}"' | \
            sort -nr | head -5)
          
          # Large cache directories
          CACHE_DIRS=$(find /var/cache /home -maxdepth 3 -type d 2>/dev/null | \
            xargs -I {} sh -c 'size=$(du -sb "{}" 2>/dev/null | cut -f1); [ "$size" -gt 104857600 ] && echo "$size:{}"' | \
            sort -nr | head -5)
          
          # System temporary files
          TEMP_SIZE=$(du -sb /tmp 2>/dev/null | cut -f1 || echo "0")
          VAR_TMP_SIZE=$(du -sb /var/tmp 2>/dev/null | cut -f1 || echo "0")
          
          # Generate migration plan
          cat > "$MIGRATION_PLAN" << EOF
          {
            "migration_metadata": {
              "hostname": "$HOSTNAME",
              "timestamp": "$(date -Iseconds)",
              "migration_mode": "$MIGRATION_MODE",
              "root_usage_percent": $ROOT_USAGE,
              "target_volume": "$TARGET_VOLUME",
              "target_usage_percent": $TARGET_USAGE,
              "target_available_bytes": $((TARGET_AVAILABLE * 1024))
            },
            "migration_candidates": {
              "docker_data": {
                "current_path": "$DOCKER_PATH",
                "size_bytes": $DOCKER_SIZE,
                "size_human": "$(numfmt --to=iec-i --suffix=B $DOCKER_SIZE 2>/dev/null || echo "$DOCKER_SIZE bytes")",
                "migration_priority": "high",
                "estimated_time": "10-30 minutes",
                "complexity": "medium",
                "steps": [
                  "Stop Docker service",
                  "Create target directory: $TARGET_VOLUME/docker",
                  "Move data: mv /var/lib/docker $TARGET_VOLUME/",
                  "Create symlink: ln -s $TARGET_VOLUME/docker /var/lib/docker",
                  "Start Docker service"
                ]
              },
              "large_logs": [
          $(echo "$LOG_DIRS" | while IFS=':' read -r size path; do
            [ -n "$size" ] && [ -n "$path" ] && cat << INNER_EOF
                {
                  "path": "$path",
                  "size_bytes": $size,
                  "size_human": "$(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo "$size bytes")",
                  "migration_action": "archive_and_symlink"
                },
          INNER_EOF
          done | sed '$ s/,$//')
              ],
              "cache_directories": [
          $(echo "$CACHE_DIRS" | while IFS=':' read -r size path; do
            [ -n "$size" ] && [ -n "$path" ] && cat << INNER_EOF
                {
                  "path": "$path",
                  "size_bytes": $size,
                  "size_human": "$(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo "$size bytes")",
                  "migration_action": "move_and_symlink"
                },
          INNER_EOF
          done | sed '$ s/,$//')
              ],
              "temporary_files": {
                "tmp_size_bytes": $TEMP_SIZE,
                "var_tmp_size_bytes": $VAR_TMP_SIZE,
                "cleanup_action": "immediate_deletion"
              }
            },
            "migration_phases": {
              "phase_1_immediate": {
                "description": "Immediate cleanup - no service interruption",
                "actions": [
                  "Clear /tmp and /var/tmp",
                  "Truncate large log files",
                  "Clean package caches",
                  "Run nix-collect-garbage"
                ],
                "estimated_recovery": "1-5GB"
              },
              "phase_2_docker": {
                "description": "Docker data migration - requires service restart",
                "actions": [
                  "Backup Docker configuration",
                  "Stop Docker service",
                  "Move Docker data to $TARGET_VOLUME",
                  "Create symlinks",
                  "Restart Docker service"
                ],
                "estimated_recovery": "$(numfmt --to=iec-i --suffix=B $DOCKER_SIZE 2>/dev/null || echo "$DOCKER_SIZE bytes")",
                "service_downtime": "5-15 minutes"
              },
              "phase_3_optimization": {
                "description": "System optimization and permanent fixes",
                "actions": [
                  "Configure log rotation policies",
                  "Set up automated cache management",
                  "Implement monitoring for disk usage",
                  "Schedule regular cleanup tasks"
                ],
                "estimated_recovery": "Ongoing prevention"
              }
            }
          }
          EOF
          
          echo "[$(date)] Migration plan created: $MIGRATION_PLAN"
          
          # Preparation phase
          if [ "$MIGRATION_MODE" = "preparation" ] || [ "$MIGRATION_MODE" = "execution" ]; then
            echo "[$(date)] === MIGRATION PREPARATION ==="
            
            # Create target directories
            mkdir -p "$TARGET_VOLUME/docker-backup"
            mkdir -p "$TARGET_VOLUME/logs-archive"
            mkdir -p "$TARGET_VOLUME/cache-migration"
            
            # Pre-migration backup
            echo "[$(date)] Creating pre-migration backup..."
            systemctl start ai-pre-cleanup-backup || echo "Backup service not available"
            
            echo "[$(date)] Preparation phase completed"
          fi
          
          # Execution phase - ONLY if explicitly requested
          if [ "$MIGRATION_MODE" = "execution" ]; then
            echo "[$(date)] === MIGRATION EXECUTION ==="
            echo "[$(date)] WARNING: Starting actual data migration"
            
            # Phase 1: Immediate cleanup
            echo "[$(date)] Phase 1: Immediate cleanup"
            
            # Clear temporary files
            find /tmp -type f -mmin +60 -delete 2>/dev/null || true
            find /var/tmp -type f -mmin +60 -delete 2>/dev/null || true
            
            # Truncate large logs (but preserve last 100 lines)
            find /var/log -name "*.log" -size +50M -exec sh -c 'tail -100 "$1" > "$1.tmp" && mv "$1.tmp" "$1"' _ {} \; 2>/dev/null || true
            
            # Nix cleanup
            nix-collect-garbage -d --delete-older-than 6h
            
            PHASE1_RECOVERY=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
            echo "[$(date)] Phase 1 complete. New root usage: $PHASE1_RECOVERY%"
            
            # Phase 2: Docker migration (only if still critical)
            if [ "$PHASE1_RECOVERY" -gt 80 ] && [ "$DOCKER_SIZE" -gt 1073741824 ]; then
              echo "[$(date)] Phase 2: Docker data migration"
              
              if systemctl is-active docker; then
                echo "[$(date)] Stopping Docker service..."
                systemctl stop docker
                
                # Backup current Docker data
                cp -r /var/lib/docker "$TARGET_VOLUME/docker-backup/" 2>/dev/null || true
                
                # Move Docker data
                echo "[$(date)] Moving Docker data to $TARGET_VOLUME..."
                if mv /var/lib/docker "$TARGET_VOLUME/docker"; then
                  # Create symlink
                  ln -s "$TARGET_VOLUME/docker" /var/lib/docker
                  echo "[$(date)] Docker data migration successful"
                  
                  # Restart Docker
                  systemctl start docker
                  echo "[$(date)] Docker service restarted"
                else
                  echo "[$(date)] ERROR: Docker migration failed, restoring backup"
                  mv "$TARGET_VOLUME/docker-backup/docker" /var/lib/docker 2>/dev/null || true
                  systemctl start docker
                fi
              fi
            fi
            
            FINAL_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
            SPACE_RECOVERED=$(($ROOT_USAGE - $FINAL_USAGE))
            
            echo "[$(date)] === MIGRATION COMPLETE ==="
            echo "[$(date)] Original usage: $ROOT_USAGE%"
            echo "[$(date)] Final usage: $FINAL_USAGE%"
            echo "[$(date)] Space recovered: $SPACE_RECOVERED%"
            
            if [ "$FINAL_USAGE" -gt 75 ]; then
              echo "[$(date)] WARNING: Usage still high, additional measures may be needed"
            else
              echo "[$(date)] SUCCESS: Usage reduced to acceptable levels"
            fi
          fi
          
          echo "[$(date)] Emergency storage migration completed"
        '';
      };
    };

    # Quick migration trigger service
    systemd.services.ai-quick-migration = {
      description = "AI Quick Migration Trigger";
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "ai-quick-migration" ''
          #!/bin/bash
          
          echo "Starting quick migration analysis..."
          
          # Check if migration is needed
          ROOT_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
          
          if [ "$ROOT_USAGE" -gt 85 ]; then
            echo "CRITICAL: Root usage $ROOT_USAGE% - starting emergency migration"
            systemctl start ai-emergency-migration
          elif [ "$ROOT_USAGE" -gt 75 ]; then
            echo "WARNING: Root usage $ROOT_USAGE% - preparing migration plan"
            # Set migration mode to preparation
            systemctl start ai-emergency-migration
          else
            echo "Root usage $ROOT_USAGE% - no migration needed"
          fi
        '';
      };
    };

    # Create directories for migration staging
    systemd.tmpfiles.rules = [
      "d ${cfg.targetVolume}/migration-staging 0755 root root -"
      "d ${cfg.targetVolume}/docker-backup 0755 root root -"
      "d ${cfg.targetVolume}/logs-archive 0755 root root -"
      "d /var/log/ai-analysis 0755 ai-analysis ai-analysis -"
    ];
  };
}