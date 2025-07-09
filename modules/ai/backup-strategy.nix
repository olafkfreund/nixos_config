# Automated Backup Strategy for Critical Configurations
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.ai.backupStrategy;
in {
  options.ai.backupStrategy = {
    enable = mkEnableOption "Enable automated backup strategy";
    
    backupPath = mkOption {
      type = types.str;
      default = "/var/backups/ai-system";
      description = "Base path for storing backups";
    };
    
    retentionDays = mkOption {
      type = types.int;
      default = 30;
      description = "Number of days to retain backups";
    };
    
    criticalMode = mkOption {
      type = types.bool;
      default = false;
      description = "Enable critical mode for frequent backups before cleanups";
    };
    
    remoteBackup = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable remote backup to other hosts";
      };
      
      targetHost = mkOption {
        type = types.str;
        default = "p620";
        description = "Target host for remote backups";
      };
      
      targetPath = mkOption {
        type = types.str;
        default = "/mnt/data/backups";
        description = "Target path on remote host";
      };
    };
  };

  config = mkIf cfg.enable {
    # Main backup service
    systemd.services.ai-critical-backup = {
      description = "AI Critical System Backup";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "ai-critical-backup" ''
          #!/bin/bash
          
          # Configuration
          BACKUP_BASE="${cfg.backupPath}"
          RETENTION_DAYS="${toString cfg.retentionDays}"
          CRITICAL_MODE="${if cfg.criticalMode then "true" else "false"}"
          REMOTE_BACKUP="${if cfg.remoteBackup.enable then "true" else "false"}"
          REMOTE_HOST="${cfg.remoteBackup.targetHost}"
          REMOTE_PATH="${cfg.remoteBackup.targetPath}"
          
          HOSTNAME=$(hostname)
          TIMESTAMP=$(date +%Y%m%d_%H%M%S)
          BACKUP_DIR="$BACKUP_BASE/$HOSTNAME/$TIMESTAMP"
          LOG_FILE="/var/log/ai-analysis/backup.log"
          
          # Ensure directories exist
          mkdir -p "$BACKUP_DIR"
          mkdir -p "$(dirname "$LOG_FILE")"
          
          # Setup logging
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1
          
          echo "[$(date)] Starting critical backup for $HOSTNAME..."
          echo "[$(date)] Backup directory: $BACKUP_DIR"
          echo "[$(date)] Critical mode: $CRITICAL_MODE"
          
          # Function to backup with error handling
          backup_item() {
            local source="$1"
            local dest="$2"
            local description="$3"
            
            echo "[$(date)] Backing up $description..."
            
            if [ -e "$source" ]; then
              if cp -rp "$source" "$dest" 2>/dev/null; then
                echo "[$(date)] ✓ Successfully backed up $description"
                return 0
              else
                echo "[$(date)] ✗ Failed to backup $description"
                return 1
              fi
            else
              echo "[$(date)] ⚠ $description not found at $source"
              return 1
            fi
          }
          
          # Critical system configurations
          echo "[$(date)] === CRITICAL SYSTEM CONFIGURATIONS ==="
          
          backup_item "/etc/nixos" "$BACKUP_DIR/nixos" "NixOS configuration"
          backup_item "/etc/machine-id" "$BACKUP_DIR/machine-id" "Machine ID"
          backup_item "/etc/ssh" "$BACKUP_DIR/ssh" "SSH configuration"
          backup_item "/etc/systemd" "$BACKUP_DIR/systemd" "Systemd configuration"
          backup_item "/etc/hosts" "$BACKUP_DIR/hosts" "Hosts file"
          backup_item "/etc/fstab" "$BACKUP_DIR/fstab" "Filesystem table"
          backup_item "/etc/passwd" "$BACKUP_DIR/passwd" "User accounts"
          backup_item "/etc/group" "$BACKUP_DIR/group" "Group accounts"
          backup_item "/etc/shadow" "$BACKUP_DIR/shadow" "Password hashes"
          
          # AI Analysis specific configurations
          echo "[$(date)] === AI ANALYSIS CONFIGURATIONS ==="
          
          backup_item "/var/lib/ai-analysis" "$BACKUP_DIR/ai-analysis" "AI Analysis data"
          backup_item "/var/log/ai-analysis" "$BACKUP_DIR/ai-analysis-logs" "AI Analysis logs"
          backup_item "/run/agenix" "$BACKUP_DIR/agenix" "Encrypted secrets"
          
          # Service-specific configurations
          echo "[$(date)] === SERVICE CONFIGURATIONS ==="
          
          if systemctl is-enabled grafana &>/dev/null; then
            backup_item "/var/lib/grafana" "$BACKUP_DIR/grafana" "Grafana data"
          fi
          
          if systemctl is-enabled prometheus &>/dev/null; then
            backup_item "/var/lib/prometheus2" "$BACKUP_DIR/prometheus" "Prometheus data"
          fi
          
          if systemctl is-enabled chromadb &>/dev/null; then
            backup_item "/var/lib/chromadb" "$BACKUP_DIR/chromadb" "ChromaDB data"
          fi
          
          if systemctl is-enabled docker &>/dev/null; then
            echo "[$(date)] Creating Docker backup metadata..."
            docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" > "$BACKUP_DIR/docker-images.txt" 2>/dev/null || true
            docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" > "$BACKUP_DIR/docker-containers.txt" 2>/dev/null || true
          fi
          
          # System state information
          echo "[$(date)] === SYSTEM STATE INFORMATION ==="
          
          # Disk usage before backup
          df -h > "$BACKUP_DIR/disk-usage.txt"
          du -sh /nix/store > "$BACKUP_DIR/nix-store-size.txt" 2>/dev/null || true
          nix-env --list-generations > "$BACKUP_DIR/nix-generations.txt" 2>/dev/null || true
          
          # System information
          uname -a > "$BACKUP_DIR/system-info.txt"
          systemctl list-units --state=failed > "$BACKUP_DIR/failed-services.txt"
          journalctl --since="24 hours ago" --priority=err > "$BACKUP_DIR/recent-errors.txt"
          
          # Network configuration
          ip addr show > "$BACKUP_DIR/network-interfaces.txt"
          ip route show > "$BACKUP_DIR/network-routes.txt"
          
          # Create backup manifest
          echo "[$(date)] Creating backup manifest..."
          cat > "$BACKUP_DIR/MANIFEST.json" << EOF
          {
            "backup_metadata": {
              "hostname": "$HOSTNAME",
              "timestamp": "$(date -Iseconds)",
              "backup_type": "critical_system",
              "critical_mode": $CRITICAL_MODE,
              "backup_path": "$BACKUP_DIR"
            },
            "system_info": {
              "kernel_version": "$(uname -r)",
              "nixos_version": "$(nixos-version 2>/dev/null || echo 'unknown')",
              "uptime": "$(uptime -p)",
              "disk_usage_root": "$(df / | tail -1 | awk '{print $5}')"
            },
            "backup_contents": [
              "nixos_configuration",
              "system_accounts",
              "ssh_configuration",
              "ai_analysis_data",
              "service_configurations",
              "system_state_snapshots"
            ],
            "retention_policy": {
              "retention_days": $RETENTION_DAYS,
              "cleanup_after": "$(date -d "+$RETENTION_DAYS days" -Iseconds)"
            }
          }
          EOF
          
          # Calculate backup size
          BACKUP_SIZE=$(du -sb "$BACKUP_DIR" | cut -f1)
          BACKUP_SIZE_HUMAN=$(du -sh "$BACKUP_DIR" | cut -f1)
          
          echo "[$(date)] Backup completed successfully"
          echo "[$(date)] Backup size: $BACKUP_SIZE_HUMAN"
          echo "[$(date)] Backup location: $BACKUP_DIR"
          
          # Remote backup if enabled
          if [ "$REMOTE_BACKUP" = "true" ]; then
            echo "[$(date)] Starting remote backup to $REMOTE_HOST..."
            
            # Create remote backup directory
            ssh "$REMOTE_HOST" "mkdir -p $REMOTE_PATH/$HOSTNAME" 2>/dev/null || {
              echo "[$(date)] ⚠ Failed to create remote directory on $REMOTE_HOST"
            }
            
            # Sync backup to remote host
            if rsync -avz --progress "$BACKUP_DIR" "$REMOTE_HOST:$REMOTE_PATH/$HOSTNAME/" 2>/dev/null; then
              echo "[$(date)] ✓ Remote backup completed successfully"
            else
              echo "[$(date)] ✗ Remote backup failed"
            fi
          fi
          
          # Cleanup old backups
          echo "[$(date)] Cleaning up backups older than $RETENTION_DAYS days..."
          find "$BACKUP_BASE/$HOSTNAME" -type d -name "[0-9]*_[0-9]*" -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true
          
          # Update latest symlink
          ln -sfn "$BACKUP_DIR" "$BACKUP_BASE/$HOSTNAME/latest"
          
          echo "[$(date)] Backup process completed successfully"
          
          # If critical mode, also create quick recovery script
          if [ "$CRITICAL_MODE" = "true" ]; then
            cat > "$BACKUP_DIR/QUICK_RECOVERY.sh" << 'EOF'
          #!/bin/bash
          # Quick recovery script for critical system restoration
          
          echo "=== EMERGENCY RECOVERY SCRIPT ==="
          echo "Backup created: $(date)"
          echo "System: $(hostname)"
          echo ""
          echo "To restore critical configurations:"
          echo "1. NixOS config: sudo cp -r nixos/* /etc/nixos/"
          echo "2. SSH config: sudo cp -r ssh/* /etc/ssh/"
          echo "3. Machine ID: sudo cp machine-id /etc/machine-id"
          echo "4. AI Analysis: sudo cp -r ai-analysis/* /var/lib/ai-analysis/"
          echo ""
          echo "After restoration, run: sudo nixos-rebuild switch"
          echo ""
          echo "=== END RECOVERY SCRIPT ==="
          EOF
            chmod +x "$BACKUP_DIR/QUICK_RECOVERY.sh"
            echo "[$(date)] Quick recovery script created: $BACKUP_DIR/QUICK_RECOVERY.sh"
          fi
        '';
      };
    };

    # Pre-cleanup backup service (triggered before aggressive cleanups)
    systemd.services.ai-pre-cleanup-backup = {
      description = "AI Pre-Cleanup Backup";
      
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "ai-pre-cleanup-backup" ''
          #!/bin/bash
          
          LOG_FILE="/var/log/ai-analysis/pre-cleanup-backup.log"
          mkdir -p "$(dirname "$LOG_FILE")"
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1
          
          echo "[$(date)] Starting pre-cleanup backup..."
          
          # Create emergency backup before any cleanup
          EMERGENCY_BACKUP="${cfg.backupPath}/$(hostname)/emergency-$(date +%Y%m%d_%H%M%S)"
          mkdir -p "$EMERGENCY_BACKUP"
          
          # Quick backup of essential items
          cp -r /etc/nixos "$EMERGENCY_BACKUP/" 2>/dev/null || true
          cp /etc/machine-id "$EMERGENCY_BACKUP/" 2>/dev/null || true
          
          # Save current system state
          df -h > "$EMERGENCY_BACKUP/pre-cleanup-disk-usage.txt"
          nix-env --list-generations > "$EMERGENCY_BACKUP/pre-cleanup-generations.txt" 2>/dev/null || true
          
          echo "[$(date)] Emergency backup completed: $EMERGENCY_BACKUP"
          echo "[$(date)] System ready for cleanup operations"
        '';
      };
    };

    # Timer for regular backups
    systemd.timers.ai-critical-backup = {
      description = "AI Critical Backup Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = if cfg.criticalMode then "*:0/4" else "daily"; # Every 4 hours in critical mode
        Persistent = true;
        RandomizedDelaySec = "15m";
      };
    };

    # Create backup directories
    systemd.tmpfiles.rules = [
      "d ${cfg.backupPath} 0755 root root -"
      "d /var/log/ai-analysis 0755 ai-analysis ai-analysis -"
    ];

    # Install backup tools
    environment.systemPackages = with pkgs; [
      rsync
      openssh
    ];
  };
}