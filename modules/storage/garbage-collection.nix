# Nix Store Garbage Collection Module
# Automatic cleanup of old generations and unused store paths
{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.storage.garbageCollection;
in
{
  options.storage.garbageCollection = {
    enable = mkEnableOption "Enable automatic Nix garbage collection";

    schedule = mkOption {
      type = types.enum [ "daily" "weekly" "monthly" ];
      default = "weekly";
      description = "Frequency of garbage collection";
    };

    keepGenerations = mkOption {
      type = types.int;
      default = 5;
      description = "Number of system generations to keep";
    };

    keepDays = mkOption {
      type = types.int;
      default = 30;
      description = "Delete store paths older than this many days";
    };

    deleteOlderThan = mkOption {
      type = types.str;
      default = "30d";
      description = "Age threshold for deletion (e.g., 30d, 14d, 7d)";
      example = "30d";
    };

    optimizeStore = mkOption {
      type = types.bool;
      default = true;
      description = "Optimize Nix store after garbage collection (deduplication)";
    };

    minFreeSpace = mkOption {
      type = types.nullOr types.int;
      default = 10;
      description = "Minimum free space in GB to maintain (null to disable)";
    };

    aggressiveCleanup = mkOption {
      type = types.bool;
      default = false;
      description = "Enable aggressive cleanup removing all old generations";
    };
  };

  config = mkIf cfg.enable {
    # Automatic garbage collection
    nix.gc = {
      automatic = true;
      dates = cfg.schedule;
      options = if cfg.aggressiveCleanup
        then "--delete-old"
        else "--delete-older-than ${cfg.deleteOlderThan}";
    };

    # Store optimization (deduplication)
    nix.optimise = mkIf cfg.optimizeStore {
      automatic = true;
      dates = [ cfg.schedule ];
    };

    # Systemd service for pre-GC disk space check
    systemd.services.nix-gc-pre-check = mkIf (cfg.minFreeSpace != null) {
      description = "Check disk space before garbage collection";
      before = [ "nix-gc.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "nix-gc-pre-check" ''
          #!/bin/bash

          LOG_FILE="/var/log/nix-gc/pre-check.log"
          mkdir -p "$(dirname "$LOG_FILE")"
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1

          echo "[$(date)] Checking disk space before garbage collection..."

          # Get available space in GB
          AVAILABLE_GB=$(df /nix/store | tail -1 | awk '{print int($4/1024/1024)}')
          MIN_REQUIRED=${toString cfg.minFreeSpace}

          echo "[$(date)] Available space: ''${AVAILABLE_GB}GB"
          echo "[$(date)] Minimum required: ''${MIN_REQUIRED}GB"

          if [ "$AVAILABLE_GB" -lt "$MIN_REQUIRED" ]; then
            echo "[$(date)] Disk space below minimum threshold - garbage collection recommended"
            exit 0
          else
            echo "[$(date)] Sufficient disk space available"
            exit 0
          fi
        '';
      };
    };

    # Enhanced garbage collection with logging
    systemd.services.nix-gc = {
      serviceConfig = {
        # Add logging for garbage collection
        StandardOutput = "journal+console";
        StandardError = "journal+console";
      };

      # Post-GC status report
      postStop = ''
        LOG_FILE="/var/log/nix-gc/summary.log"
        mkdir -p "$(dirname "$LOG_FILE")"

        {
          echo "==== Garbage Collection Report ===="
          echo "Date: $(date)"
          echo ""
          echo "Disk Usage:"
          df -h /nix/store | tail -1
          echo ""
          echo "Store Size:"
          du -sh /nix/store 2>/dev/null || echo "Unable to calculate"
          echo ""
          echo "System Generations:"
          nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -10
          echo "===================================="
        } | tee -a "$LOG_FILE"
      '';
    };

    # Weekly generation cleanup (keep only recent generations)
    systemd.services.nix-generation-cleanup = mkIf (!cfg.aggressiveCleanup) {
      description = "Clean up old NixOS generations";
      after = [ "nix-gc.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "nix-generation-cleanup" ''
          #!/bin/bash

          LOG_FILE="/var/log/nix-gc/generation-cleanup.log"
          mkdir -p "$(dirname "$LOG_FILE")"
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1

          echo "[$(date)] Starting generation cleanup..."
          echo "[$(date)] Keeping last ${toString cfg.keepGenerations} generations"

          # Get current generation
          CURRENT=$(nix-env --list-generations --profile /nix/var/nix/profiles/system | grep current | awk '{print $1}')

          # List all generations
          GENERATIONS=$(nix-env --list-generations --profile /nix/var/nix/profiles/system | awk '{print $1}' | grep -v current | sort -rn)

          # Keep only the last N generations
          KEEP_COUNT=0
          for gen in $GENERATIONS; do
            if [ "$gen" = "$CURRENT" ]; then
              continue
            fi

            KEEP_COUNT=$((KEEP_COUNT + 1))

            if [ $KEEP_COUNT -gt ${toString cfg.keepGenerations} ]; then
              echo "[$(date)] Deleting generation $gen"
              nix-env --delete-generations $gen --profile /nix/var/nix/profiles/system || true
            else
              echo "[$(date)] Keeping generation $gen"
            fi
          done

          echo "[$(date)] Generation cleanup completed"
        '';
      };
    };

    # Create log directories
    systemd.tmpfiles.rules = [
      "d /var/log/nix-gc 0755 root root -"
    ];

    # Add garbage collection monitoring script
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "nix-gc-status" ''
        #!/bin/bash

        echo "==== Nix Garbage Collection Status ===="
        echo ""
        echo "Schedule: ${cfg.schedule}"
        echo "Delete older than: ${cfg.deleteOlderThan}"
        echo "Keep generations: ${toString cfg.keepGenerations}"
        ${optionalString (cfg.minFreeSpace != null) ''
        echo "Minimum free space: ${toString cfg.minFreeSpace}GB"
        ''}
        echo ""
        echo "Current Disk Usage:"
        df -h /nix/store | tail -1
        echo ""
        echo "Store Size:"
        du -sh /nix/store 2>/dev/null || echo "Unable to calculate"
        echo ""
        echo "System Generations:"
        nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -10
        echo ""
        echo "Last GC Run (from systemd):"
        systemctl status nix-gc.service | grep -A 3 "Loaded:"
        echo ""
        echo "Next GC Run:"
        systemctl list-timers nix-gc.timer | grep nix-gc
        echo ""
        echo "Recent GC Logs:"
        journalctl -u nix-gc.service -n 20 --no-pager
        echo "========================================"
      '')

      (pkgs.writeShellScriptBin "nix-gc-now" ''
        #!/bin/bash

        echo "Running garbage collection now..."
        sudo systemctl start nix-gc.service
        echo "Checking status..."
        sleep 2
        sudo systemctl status nix-gc.service
      '')
    ];
  };
}
