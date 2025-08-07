# Storage Performance Optimization Module
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.storage.performanceOptimization;
in
{
  options.storage.performanceOptimization = {
    enable = mkEnableOption "Enable storage performance optimization";

    profile = mkOption {
      type = types.enum [ "performance" "balanced" "reliability" ];
      default = "balanced";
      description = "Storage optimization profile";
    };

    ioSchedulerOptimization = {
      enable = mkEnableOption "Enable I/O scheduler optimization";

      dynamicScheduling = mkOption {
        type = types.bool;
        default = true;
        description = "Enable dynamic I/O scheduler selection based on workload";
      };

      ssdOptimization = mkOption {
        type = types.bool;
        default = true;
        description = "Enable SSD-specific optimizations";
      };

      hddOptimization = mkOption {
        type = types.bool;
        default = true;
        description = "Enable HDD-specific optimizations";
      };
    };

    filesystemOptimization = {
      enable = mkEnableOption "Enable filesystem optimization";

      readaheadOptimization = mkOption {
        type = types.bool;
        default = true;
        description = "Enable readahead optimization";
      };

      cacheOptimization = mkOption {
        type = types.bool;
        default = true;
        description = "Enable filesystem cache optimization";
      };

      compressionOptimization = mkOption {
        type = types.bool;
        default = false;
        description = "Enable filesystem compression optimization";
      };
    };

    nvmeOptimization = {
      enable = mkEnableOption "Enable NVMe-specific optimizations";

      queueDepth = mkOption {
        type = types.int;
        default = 32;
        description = "NVMe queue depth optimization";
      };

      polling = mkOption {
        type = types.bool;
        default = true;
        description = "Enable NVMe polling for low latency";
      };

      multiQueue = mkOption {
        type = types.bool;
        default = true;
        description = "Enable NVMe multi-queue support";
      };
    };

    diskCacheOptimization = {
      enable = mkEnableOption "Enable disk cache optimization";

      writeCache = mkOption {
        type = types.bool;
        default = true;
        description = "Enable write cache optimization";
      };

      readCache = mkOption {
        type = types.bool;
        default = true;
        description = "Enable read cache optimization";
      };

      barrierOptimization = mkOption {
        type = types.bool;
        default = false;
        description = "Disable write barriers for performance (unsafe)";
      };
    };

    tmpfsOptimization = {
      enable = mkEnableOption "Enable tmpfs optimization for performance";

      tmpSize = mkOption {
        type = types.str;
        default = "2G";
        description = "Size of /tmp tmpfs";
      };

      varTmpSize = mkOption {
        type = types.str;
        default = "1G";
        description = "Size of /var/tmp tmpfs";
      };

      devShmSize = mkOption {
        type = types.str;
        default = "50%";
        description = "Size of /dev/shm tmpfs";
      };
    };
  };

  config = mkIf cfg.enable {
    # Storage Performance Optimization Service
    systemd.services.storage-performance-optimizer = {
      description = "Storage Performance Optimization Service";
      after = [ "local-fs.target" ];
      wants = [ "local-fs.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        ExecStart = pkgs.writeShellScript "storage-performance-optimizer" ''
          #!/bin/bash

          LOG_FILE="/var/log/storage-tuning/optimizer.log"
          mkdir -p "$(dirname "$LOG_FILE")"
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1

          echo "[$(date)] Starting storage performance optimization..."
          echo "[$(date)] Profile: ${cfg.profile}"

          # Detect storage devices
          echo "[$(date)] Detecting storage devices..."

          # Get all block devices
          BLOCK_DEVICES=$(lsblk -nd -o NAME,TYPE | grep disk | awk '{print $1}')

          for device in $BLOCK_DEVICES; do
            DEVICE_PATH="/dev/$device"
            echo "[$(date)] Processing device: $DEVICE_PATH"

            # Detect device type
            if [ -f "/sys/block/$device/queue/rotational" ]; then
              ROTATIONAL=$(cat "/sys/block/$device/queue/rotational")

              if [ "$ROTATIONAL" = "0" ]; then
                DEVICE_TYPE="ssd"
                echo "[$(date)] Detected SSD: $DEVICE_PATH"
              else
                DEVICE_TYPE="hdd"
                echo "[$(date)] Detected HDD: $DEVICE_PATH"
              fi
            else
              DEVICE_TYPE="unknown"
              echo "[$(date)] Unknown device type: $DEVICE_PATH"
            fi

            # I/O scheduler optimization
            ${optionalString cfg.ioSchedulerOptimization.enable ''
              echo "[$(date)] Optimizing I/O scheduler for $DEVICE_PATH..."

              SCHEDULER_PATH="/sys/block/$device/queue/scheduler"
              if [ -f "$SCHEDULER_PATH" ]; then
                ${optionalString cfg.ioSchedulerOptimization.dynamicScheduling ''
                  case "$DEVICE_TYPE" in
                    "ssd")
                      ${optionalString cfg.ioSchedulerOptimization.ssdOptimization ''
                        # Use none or mq-deadline for SSDs
                        if grep -q "none" "$SCHEDULER_PATH"; then
                          echo none > "$SCHEDULER_PATH"
                          echo "[$(date)] Set scheduler to 'none' for SSD $DEVICE_PATH"
                        elif grep -q "mq-deadline" "$SCHEDULER_PATH"; then
                          echo mq-deadline > "$SCHEDULER_PATH"
                          echo "[$(date)] Set scheduler to 'mq-deadline' for SSD $DEVICE_PATH"
                        fi
                      ''}
                      ;;
                    "hdd")
                      ${optionalString cfg.ioSchedulerOptimization.hddOptimization ''
                        # Use bfq or mq-deadline for HDDs
                        if grep -q "bfq" "$SCHEDULER_PATH"; then
                          echo bfq > "$SCHEDULER_PATH"
                          echo "[$(date)] Set scheduler to 'bfq' for HDD $DEVICE_PATH"
                        elif grep -q "mq-deadline" "$SCHEDULER_PATH"; then
                          echo mq-deadline > "$SCHEDULER_PATH"
                          echo "[$(date)] Set scheduler to 'mq-deadline' for HDD $DEVICE_PATH"
                        fi
                      ''}
                      ;;
                  esac
                ''}
              fi
            ''}

            # Queue depth optimization
            QUEUE_DEPTH_PATH="/sys/block/$device/queue/nr_requests"
            if [ -f "$QUEUE_DEPTH_PATH" ]; then
              case "${cfg.profile}" in
                "performance")
                  echo 256 > "$QUEUE_DEPTH_PATH" 2>/dev/null || true
                  echo "[$(date)] Set queue depth to 256 for $DEVICE_PATH"
                  ;;
                "balanced")
                  echo 128 > "$QUEUE_DEPTH_PATH" 2>/dev/null || true
                  echo "[$(date)] Set queue depth to 128 for $DEVICE_PATH"
                  ;;
                "reliability")
                  echo 64 > "$QUEUE_DEPTH_PATH" 2>/dev/null || true
                  echo "[$(date)] Set queue depth to 64 for $DEVICE_PATH"
                  ;;
              esac
            fi

            # Read-ahead optimization
            ${optionalString cfg.filesystemOptimization.readaheadOptimization ''
              READAHEAD_PATH="/sys/block/$device/queue/read_ahead_kb"
              if [ -f "$READAHEAD_PATH" ]; then
                case "$DEVICE_TYPE" in
                  "ssd")
                    echo 128 > "$READAHEAD_PATH" 2>/dev/null || true
                    echo "[$(date)] Set read-ahead to 128KB for SSD $DEVICE_PATH"
                    ;;
                  "hdd")
                    echo 4096 > "$READAHEAD_PATH" 2>/dev/null || true
                    echo "[$(date)] Set read-ahead to 4MB for HDD $DEVICE_PATH"
                    ;;
                esac
              fi
            ''}

            # NVMe-specific optimizations
            ${optionalString cfg.nvmeOptimization.enable ''
              if [[ "$device" == nvme* ]]; then
                echo "[$(date)] Applying NVMe optimizations for $DEVICE_PATH..."

                ${optionalString cfg.nvmeOptimization.polling ''
                  # Enable polling for low latency
                  POLL_PATH="/sys/block/$device/queue/io_poll"
                  if [ -f "$POLL_PATH" ]; then
                    echo 1 > "$POLL_PATH" 2>/dev/null || true
                    echo "[$(date)] Enabled NVMe polling for $DEVICE_PATH"
                  fi
                ''}

                ${optionalString cfg.nvmeOptimization.multiQueue ''
                  # Optimize queue count
                  WBT_PATH="/sys/block/$device/queue/wbt_lat_usec"
                  if [ -f "$WBT_PATH" ]; then
                    echo 0 > "$WBT_PATH" 2>/dev/null || true
                    echo "[$(date)] Disabled write back throttling for $DEVICE_PATH"
                  fi
                ''}
              fi
            ''}

            # Disk cache optimization
            ${optionalString cfg.diskCacheOptimization.enable ''
              echo "[$(date)] Optimizing disk cache for $DEVICE_PATH..."

              ${optionalString cfg.diskCacheOptimization.writeCache ''
                # Enable write cache if available
                if command -v hdparm >/dev/null 2>&1; then
                  hdparm -W1 "$DEVICE_PATH" 2>/dev/null || true
                  echo "[$(date)] Enabled write cache for $DEVICE_PATH"
                fi
              ''}

              ${optionalString cfg.diskCacheOptimization.readCache ''
                # Enable read cache if available
                if command -v hdparm >/dev/null 2>&1; then
                  hdparm -A1 "$DEVICE_PATH" 2>/dev/null || true
                  echo "[$(date)] Enabled read cache for $DEVICE_PATH"
                fi
              ''}
            ''}
          done

          # Filesystem-level optimizations
          ${optionalString cfg.filesystemOptimization.enable ''
            echo "[$(date)] Applying filesystem optimizations..."

            ${optionalString cfg.filesystemOptimization.cacheOptimization ''
              # Optimize filesystem cache settings
              case "${cfg.profile}" in
                "performance")
                  echo 5 > /proc/sys/vm/dirty_background_ratio
                  echo 10 > /proc/sys/vm/dirty_ratio
                  echo 1500 > /proc/sys/vm/dirty_writeback_centisecs
                  echo 500 > /proc/sys/vm/dirty_expire_centisecs
                  echo "[$(date)] Applied performance filesystem cache settings"
                  ;;
                "balanced")
                  echo 10 > /proc/sys/vm/dirty_background_ratio
                  echo 20 > /proc/sys/vm/dirty_ratio
                  echo 1500 > /proc/sys/vm/dirty_writeback_centisecs
                  echo 3000 > /proc/sys/vm/dirty_expire_centisecs
                  echo "[$(date)] Applied balanced filesystem cache settings"
                  ;;
                "reliability")
                  echo 5 > /proc/sys/vm/dirty_background_ratio
                  echo 10 > /proc/sys/vm/dirty_ratio
                  echo 500 > /proc/sys/vm/dirty_writeback_centisecs
                  echo 1000 > /proc/sys/vm/dirty_expire_centisecs
                  echo "[$(date)] Applied reliability filesystem cache settings"
                  ;;
              esac
            ''}
          ''}

          echo "[$(date)] Storage performance optimization completed"
        '';
      };
    };

    # Storage Performance Monitor
    systemd.services.storage-performance-monitor = {
      description = "Storage Performance Monitor";
      after = [ "storage-performance-optimizer.service" ];
      wants = [ "storage-performance-optimizer.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        Restart = "always";
        RestartSec = "30s";
        Environment = [
          "PATH=${lib.makeBinPath (with pkgs; [
            sysstat    # iostat
            gawk       # awk
            coreutils  # basic utilities
            util-linux # lsblk
            procps     # general process utilities
            gnugrep    # grep
            gnused     # sed
          ])}"
        ];
        ExecStart = pkgs.writeShellScript "storage-performance-monitor" ''
                    #!/bin/bash

                    METRICS_FILE="/var/lib/storage-tuning/metrics.json"
                    mkdir -p "$(dirname "$METRICS_FILE")"

                    while true; do
                      TIMESTAMP=$(date -Iseconds)

                      # Collect I/O statistics
                      IO_STATS=$(iostat -x 1 1 | tail -n +4 | while read line; do
                        if [[ "$line" =~ ^[a-zA-Z] ]]; then
                          DEVICE=$(echo "$line" | awk '{print $1}')
                          UTIL=$(echo "$line" | awk '{print $NF}')
                          AWAIT=$(echo "$line" | awk '{print $(NF-1)}')
                          IOPS=$(echo "$line" | awk '{print $4+$5}')
                          echo "\"$DEVICE\": {\"utilization\": \"$UTIL\", \"await\": \"$AWAIT\", \"iops\": \"$IOPS\"}"
                        fi
                      done | paste -sd, -)

                      # Disk usage information
                      DISK_USAGE=$(df -h | grep -E '^/dev/' | while read line; do
                        DEVICE=$(echo "$line" | awk '{print $1}')
                        USAGE=$(echo "$line" | awk '{print $5}' | sed 's/%//')
                        MOUNT=$(echo "$line" | awk '{print $6}')
                        echo "\"$DEVICE\": {\"usage_percent\": $USAGE, \"mount\": \"$MOUNT\"}"
                      done | paste -sd, -)

                      # Memory usage for caching
                      CACHE_STATS=$(free -b | grep -E '^(Mem|Buffers|Cached)' | awk '
                        /^Mem:/ { total=$2; used=$3; free=$4; available=$7 }
                        END {
                          cache_used = total - available - free
                          cache_percent = (cache_used * 100) / total
                          printf "\"cache_used_bytes\": %d, \"cache_percent\": %.1f", cache_used, cache_percent
                        }
                      ')

                      # Create metrics JSON
                      cat > "$METRICS_FILE" << EOF
                      {
                        "timestamp": "$TIMESTAMP",
                        "io_devices": { $IO_STATS },
                        "disk_usage": { $DISK_USAGE },
                        "cache_stats": { $CACHE_STATS },
                        "profile": "${cfg.profile}"
                      }
          EOF

                      sleep 60
                    done
        '';
      };
    };

    # Tmpfs optimization
    fileSystems = mkIf cfg.tmpfsOptimization.enable {
      "/tmp" = mkIf (cfg.tmpfsOptimization.tmpSize != "") {
        device = "tmpfs";
        fsType = "tmpfs";
        options = [ "rw" "nosuid" "nodev" "size=${cfg.tmpfsOptimization.tmpSize}" ];
      };

      "/var/tmp" = mkIf (cfg.tmpfsOptimization.varTmpSize != "") {
        device = "tmpfs";
        fsType = "tmpfs";
        options = [ "rw" "nosuid" "nodev" "size=${cfg.tmpfsOptimization.varTmpSize}" ];
      };

      "/dev/shm" = mkIf (cfg.tmpfsOptimization.devShmSize != "") {
        device = "tmpfs";
        fsType = "tmpfs";
        options = [ "rw" "nosuid" "nodev" "size=${cfg.tmpfsOptimization.devShmSize}" ];
      };
    };

    # Storage optimization kernel parameters
    boot.kernel.sysctl = mkIf cfg.enable {
      # VM settings for storage performance (lower priority than resource manager)
      "vm.dirty_writeback_centisecs" = mkDefault (
        if cfg.profile == "performance" then 1500
        else if cfg.profile == "balanced" then 1500
        else 500
      );
      "vm.dirty_expire_centisecs" = mkDefault (
        if cfg.profile == "performance" then 500
        else if cfg.profile == "balanced" then 3000
        else 1000
      );

      # I/O settings (avoid conflicts with resource manager)

      # Read-ahead settings
      "vm.page-cluster" = mkDefault 3; # Optimize page clustering
    };

    # Storage performance packages
    environment.systemPackages = with pkgs; [
      iotop # I/O monitoring
      sysstat # Contains iostat and other system statistics tools
      hdparm # Hard disk parameters
      smartmontools # SMART monitoring
      nvme-cli # NVMe management
      fio # Flexible I/O tester
      bonnie # Filesystem benchmarking
    ];

    # Create directories
    systemd.tmpfiles.rules = [
      "d /var/lib/storage-tuning 0755 root root -"
      "d /var/log/storage-tuning 0755 root root -"
    ];

    # Enable TRIM for SSDs
    services.fstrim = {
      enable = true;
      interval = "weekly";
    };

    # SMART monitoring
    services.smartd = {
      enable = true;
      autodetect = true;
      notifications = {
        x11.enable = false;
        wall.enable = true;
        mail = {
          enable = false; # Disable email notifications by default
        };
      };
    };
  };
}
