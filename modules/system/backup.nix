# Description: Automated backup solutions with multiple backends
# Category: system (Backup Module)
{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.system.backup = {
    enable = lib.mkEnableOption "backup system";

    strategy = lib.mkOption {
      type = lib.types.enum ["local" "remote" "hybrid"];
      default = "local";
      description = "Backup strategy to use";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "Backup schedule (systemd timer format)";
      example = "weekly";
    };

    retention = {
      daily = lib.mkOption {
        type = lib.types.int;
        default = 7;
        description = "Number of daily backups to keep";
      };

      weekly = lib.mkOption {
        type = lib.types.int;
        default = 4;
        description = "Number of weekly backups to keep";
      };

      monthly = lib.mkOption {
        type = lib.types.int;
        default = 12;
        description = "Number of monthly backups to keep";
      };
    };

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["/home" "/etc" "/var/lib"];
      description = "Paths to backup";
      example = ["/home/user/documents" "/etc/nixos"];
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "**/.cache"
        "**/.tmp"
        "**/node_modules"
        "**/__pycache__"
      ];
      description = "Patterns to exclude from backup";
    };

    destinations = {
      local = {
        path = lib.mkOption {
          type = lib.types.str;
          default = "/var/backup";
          description = "Local backup destination path";
        };
      };

      remote = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable remote backup";
        };

        repository = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Remote repository URL";
          example = "sftp:backup-server:/backups/hostname";
        };

        passwordFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Path to file containing backup password";
          example = "/run/agenix/backup-password";
        };
      };
    };

    compression = lib.mkOption {
      type = lib.types.enum ["auto" "lz4" "zstd" "lzma" "none"];
      default = "auto";
      description = "Compression algorithm to use";
    };

    encryption = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable backup encryption";
    };

    healthCheck = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable backup health monitoring";
      };

      webhookUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Webhook URL for health check notifications";
      };
    };
  };

  config = lib.mkIf config.modules.system.backup.enable {
    # Install backup tools
    environment.systemPackages = with pkgs; [
      restic
      borgbackup
      rclone
    ];

    # Create backup user
    users.users.backup = {
      description = "Backup service user";
      isSystemUser = true;
      group = "backup";
      home = "/var/lib/backup";
      createHome = true;
    };

    users.groups.backup = {};

    # Local backup directory
    systemd.tmpfiles.rules = [
      "d '${config.modules.system.backup.destinations.local.path}' 0755 backup backup -"
      "d '/var/lib/backup' 0755 backup backup -"
      "d '/var/log/backup' 0755 backup backup -"
    ];

    # Backup script
    systemd.services.backup = {
      description = "System Backup Service";
      path = with pkgs; [restic borgbackup rclone curl];

      serviceConfig = {
        Type = "oneshot";
        User = "backup";
        Group = "backup";
        ExecStart = pkgs.writeShellScript "backup.sh" ''
          set -euo pipefail

          LOG_FILE="/var/log/backup/backup-$(date +%Y%m%d_%H%M%S).log"
          BACKUP_NAME="$(hostname)-$(date +%Y%m%d_%H%M%S)"

          log() {
            echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
          }

          health_check() {
            local status="$1"
            local message="$2"

            ${lib.optionalString (config.modules.system.backup.healthCheck.webhookUrl != null) ''
            if [ -n "${config.modules.system.backup.healthCheck.webhookUrl}" ]; then
              curl -X POST "${config.modules.system.backup.healthCheck.webhookUrl}" \
                -H "Content-Type: application/json" \
                -d "{\"status\":\"$status\",\"message\":\"$message\",\"hostname\":\"$(hostname)\"}" || true
            fi
          ''}
          }

          log "Starting backup: $BACKUP_NAME"

          # Create restic repository if it doesn't exist
          export RESTIC_REPOSITORY="${config.modules.system.backup.destinations.local.path}"
          ${lib.optionalString (config.modules.system.backup.destinations.remote.passwordFile != null) ''
            export RESTIC_PASSWORD_FILE="${config.modules.system.backup.destinations.remote.passwordFile}"
          ''}

          if ! restic snapshots >/dev/null 2>&1; then
            log "Initializing backup repository"
            restic init
          fi

          # Perform backup
          EXCLUDE_ARGS=""
          ${lib.concatMapStringsSep "\n" (pattern: ''
              EXCLUDE_ARGS="$EXCLUDE_ARGS --exclude='${pattern}'"
            '')
            config.modules.system.backup.exclude}

          if eval "restic backup ${lib.concatStringsSep " " config.modules.system.backup.paths} $EXCLUDE_ARGS --tag=auto --compression=${config.modules.system.backup.compression}"; then
            log "Backup completed successfully"

            # Apply retention policy
            restic forget \
              --keep-daily=${toString config.modules.system.backup.retention.daily} \
              --keep-weekly=${toString config.modules.system.backup.retention.weekly} \
              --keep-monthly=${toString config.modules.system.backup.retention.monthly} \
              --prune

            health_check "success" "Backup completed successfully"
          else
            log "Backup failed"
            health_check "failure" "Backup failed"
            exit 1
          fi
        '';

        # Security hardening
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [
          config.modules.system.backup.destinations.local.path
          "/var/lib/backup"
          "/var/log/backup"
        ];
        ReadOnlyPaths = config.modules.system.backup.paths;
      };
    };

    # Backup timer
    systemd.timers.backup = {
      description = "System Backup Timer";
      wantedBy = ["timers.target"];

      timerConfig = {
        OnCalendar = config.modules.system.backup.schedule;
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };

    # Remote backup service (if enabled)
    systemd.services.backup-remote = lib.mkIf config.modules.system.backup.destinations.remote.enable {
      description = "Remote Backup Sync";
      after = ["backup.service"];
      wants = ["backup.service"];

      serviceConfig = {
        Type = "oneshot";
        User = "backup";
        Group = "backup";
        ExecStart = pkgs.writeShellScript "backup-remote.sh" ''
          set -euo pipefail

          log() {
            echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
          }

          log "Starting remote backup sync"

          # Sync to remote repository
          rclone sync "${config.modules.system.backup.destinations.local.path}" \
            "${config.modules.system.backup.destinations.remote.repository}" \
            --progress \
            --transfers=4

          log "Remote sync completed"
        '';
      };
    };

    # Backup verification service
    systemd.services.backup-verify = {
      description = "Backup Verification";

      serviceConfig = {
        Type = "oneshot";
        User = "backup";
        Group = "backup";
        ExecStart = pkgs.writeShellScript "backup-verify.sh" ''
          set -euo pipefail

          export RESTIC_REPOSITORY="${config.modules.system.backup.destinations.local.path}"
          ${lib.optionalString (config.modules.system.backup.destinations.remote.passwordFile != null) ''
            export RESTIC_PASSWORD_FILE="${config.modules.system.backup.destinations.remote.passwordFile}"
          ''}

          echo "Verifying backup integrity..."
          restic check --read-data-subset=5%

          echo "Listing recent snapshots..."
          restic snapshots --latest=5
        '';
      };
    };

    # Weekly verification timer
    systemd.timers.backup-verify = {
      description = "Backup Verification Timer";
      wantedBy = ["timers.target"];

      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
      };
    };

    # Assertions for configuration validation
    assertions = [
      {
        assertion = config.modules.system.backup.paths != [];
        message = "modules.system.backup.paths cannot be empty";
      }
      {
        assertion =
          !config.modules.system.backup.destinations.remote.enable
          || config.modules.system.backup.destinations.remote.repository != "";
        message = "Remote repository must be specified when remote backup is enabled";
      }
    ];
  };
}
