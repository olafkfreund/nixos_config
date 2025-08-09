# Dynamic System Resource Manager Module
{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.system.resourceManager;
in
{
  options.system.resourceManager = {
    enable = mkEnableOption "Enable dynamic system resource management";

    profile = mkOption {
      type = types.enum [ "performance" "balanced" "power-save" ];
      default = "balanced";
      description = "Resource management profile";
    };

    cpuManagement = {
      enable = mkEnableOption "Enable CPU resource management";

      dynamicGovernor = mkOption {
        type = types.bool;
        default = true;
        description = "Enable dynamic CPU governor switching";
      };

      affinityOptimization = mkOption {
        type = types.bool;
        default = true;
        description = "Enable CPU affinity optimization";
      };

      coreReservation = mkOption {
        type = types.bool;
        default = false;
        description = "Reserve CPU cores for critical processes";
      };

      reservedCores = mkOption {
        type = types.int;
        default = 2;
        description = "Number of CPU cores to reserve";
      };
    };

    memoryManagement = {
      enable = mkEnableOption "Enable memory resource management";

      dynamicSwap = mkOption {
        type = types.bool;
        default = true;
        description = "Enable dynamic swap management";
      };

      hugePagesOptimization = mkOption {
        type = types.bool;
        default = true;
        description = "Enable huge pages optimization";
      };

      memoryCompression = mkOption {
        type = types.bool;
        default = false;
        description = "Enable memory compression (zram)";
      };

      oomProtection = mkOption {
        type = types.bool;
        default = true;
        description = "Enable OOM protection for critical services";
      };
    };

    ioManagement = {
      enable = mkEnableOption "Enable I/O resource management";

      dynamicScheduler = mkOption {
        type = types.bool;
        default = true;
        description = "Enable dynamic I/O scheduler selection";
      };

      ioNiceOptimization = mkOption {
        type = types.bool;
        default = true;
        description = "Enable I/O nice optimization";
      };

      cacheOptimization = mkOption {
        type = types.bool;
        default = true;
        description = "Enable file system cache optimization";
      };
    };

    networkManagement = {
      enable = mkEnableOption "Enable network resource management";

      trafficShaping = mkOption {
        type = types.bool;
        default = false;
        description = "Enable network traffic shaping";
      };

      connectionOptimization = mkOption {
        type = types.bool;
        default = true;
        description = "Enable connection optimization";
      };
    };

    workloadProfiles = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          cpuPriority = mkOption {
            type = types.int;
            default = 0;
            description = "CPU priority for this workload";
          };

          memoryLimit = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Memory limit for this workload";
          };

          ioClass = mkOption {
            type = types.int;
            default = 2;
            description = "I/O class for this workload (1=RT, 2=BE, 3=IDLE)";
          };

          ioPriority = mkOption {
            type = types.int;
            default = 4;
            description = "I/O priority within class (0-7)";
          };

          cpuAffinity = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "CPU affinity mask";
          };
        };
      });
      default = {
        ai-workload = {
          cpuPriority = -10;
          ioClass = 1;
          ioPriority = 2;
        };
        monitoring = {
          cpuPriority = -5;
          ioClass = 2;
          ioPriority = 3;
        };
        background = {
          cpuPriority = 10;
          ioClass = 3;
          ioPriority = 7;
        };
      };
      description = "Workload-specific resource profiles";
    };
  };

  config = mkIf cfg.enable {
    # Dynamic Resource Manager Service
    systemd.services.dynamic-resource-manager = {
      description = "Dynamic System Resource Manager";
      after = [ "multi-user.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        Restart = "always";
        RestartSec = "10s";
        Environment = [
          "PATH=${lib.makeBinPath (with pkgs; [
            bc # mathematical calculations
            procps # free, top, pgrep
            gawk # awk
            coreutils # basic utilities
            util-linux # renice, ionice, taskset
            gnugrep # grep
            gnused # sed
          ])}"
        ];
        ExecStart = pkgs.writeShellScript "dynamic-resource-manager" ''
          #!/bin/bash

          LOG_FILE="/var/log/resource-manager/manager.log"
          mkdir -p "$(dirname "$LOG_FILE")"
          exec 1> >(tee -a "$LOG_FILE")
          exec 2>&1

          echo "[$(date)] Starting Dynamic Resource Manager..."
          echo "[$(date)] Profile: ${cfg.profile}"

          # Function to get system load
          get_load() {
            uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//'
          }

          # Function to get memory pressure
          get_memory_pressure() {
            free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}'
          }

          # Function to get CPU usage
          get_cpu_usage() {
            top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' | cut -d. -f1
          }

          # Function to optimize CPU governor
          optimize_cpu_governor() {
            local load=$1
            local cpu_usage=$2

            ${optionalString cfg.cpuManagement.dynamicGovernor ''
            if (( $(echo "$load > 2.0" | bc -l) )) || [ "$cpu_usage" -gt 80 ]; then
              # High load - use performance governor
              for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                if [ -f "$cpu" ]; then
                  echo performance > "$cpu" 2>/dev/null || true
                fi
              done
              echo "[$(date)] CPU governor set to performance (load: $load, usage: $cpu_usage%)"
            elif (( $(echo "$load < 0.5" | bc -l) )) && [ "$cpu_usage" -lt 20 ]; then
              # Low load - use powersave governor
              for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                if [ -f "$cpu" ]; then
                  echo powersave > "$cpu" 2>/dev/null || true
                fi
              done
              echo "[$(date)] CPU governor set to powersave (load: $load, usage: $cpu_usage%)"
            else
              # Medium load - use ondemand governor
              for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                if [ -f "$cpu" ]; then
                  echo ondemand > "$cpu" 2>/dev/null || true
                fi
              done
              echo "[$(date)] CPU governor set to ondemand (load: $load, usage: $cpu_usage%)"
            fi
          ''}
          }

          # Function to optimize memory management
          optimize_memory() {
            local memory_pressure=$1

            ${optionalString cfg.memoryManagement.dynamicSwap ''
            if (( $(echo "$memory_pressure > 85.0" | bc -l) )); then
              # High memory pressure - reduce swappiness
              echo 1 > /proc/sys/vm/swappiness
              echo "[$(date)] Memory pressure high ($memory_pressure%), reduced swappiness"
            elif (( $(echo "$memory_pressure < 50.0" | bc -l) )); then
              # Low memory pressure - normal swappiness
              echo 60 > /proc/sys/vm/swappiness
              echo "[$(date)] Memory pressure low ($memory_pressure%), normal swappiness"
            fi
          ''}

            ${optionalString cfg.memoryManagement.hugePagesOptimization ''
            # Optimize huge pages based on memory usage
            if (( $(echo "$memory_pressure > 70.0" | bc -l) )); then
              echo madvise > /sys/kernel/mm/transparent_hugepage/enabled
            else
              echo always > /sys/kernel/mm/transparent_hugepage/enabled
            fi
          ''}
          }

          # Function to optimize I/O scheduler
          optimize_io_scheduler() {
            local load=$1

            ${optionalString cfg.ioManagement.dynamicScheduler ''
            for disk in /sys/block/*/queue/scheduler; do
              if [ -f "$disk" ]; then
                if (( $(echo "$load > 1.5" | bc -l) )); then
                  # High load - use deadline scheduler
                  echo deadline > "$disk" 2>/dev/null || true
                else
                  # Normal load - use CFQ scheduler
                  echo cfq > "$disk" 2>/dev/null || true
                fi
              fi
            done
            echo "[$(date)] I/O scheduler optimized for load: $load"
          ''}
          }

          # Function to apply workload profiles
          apply_workload_profiles() {
            ${concatStringsSep "\n" (mapAttrsToList (name: profile: ''
              # Apply profile for ${name}
              for pid in $(pgrep -f "${name}" 2>/dev/null || true); do
                if [ -n "$pid" ]; then
                  # Set CPU priority
                  renice ${toString profile.cpuPriority} "$pid" 2>/dev/null || true

                  # Set I/O priority
                  ionice -c ${toString profile.ioClass} -n ${toString profile.ioPriority} -p "$pid" 2>/dev/null || true

                  ${optionalString (profile.cpuAffinity != null) ''
                # Set CPU affinity
                taskset -cp ${profile.cpuAffinity} "$pid" 2>/dev/null || true
              ''}
                fi
              done
            '')
            cfg.workloadProfiles)}
          }

          # Main monitoring loop
          while true; do
            # Get current system metrics
            LOAD=$(get_load)
            MEMORY_PRESSURE=$(get_memory_pressure)
            CPU_USAGE=$(get_cpu_usage)

            echo "[$(date)] System metrics - Load: $LOAD, Memory: $MEMORY_PRESSURE%, CPU: $CPU_USAGE%"

            # Apply optimizations
            optimize_cpu_governor "$LOAD" "$CPU_USAGE"
            optimize_memory "$MEMORY_PRESSURE"
            optimize_io_scheduler "$LOAD"
            apply_workload_profiles

            # Wait before next check
            sleep 30
          done
        '';
      };
    };

    # CPU Core Reservation Service
    systemd.services.cpu-core-reservation = mkIf cfg.cpuManagement.coreReservation {
      description = "CPU Core Reservation for Critical Processes";
      after = [ "multi-user.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        ExecStart = pkgs.writeShellScript "cpu-core-reservation" ''
          #!/bin/bash

          TOTAL_CORES=$(nproc)
          RESERVED_CORES=${toString cfg.cpuManagement.reservedCores}

          if [ "$RESERVED_CORES" -ge "$TOTAL_CORES" ]; then
            echo "Error: Cannot reserve $RESERVED_CORES cores on $TOTAL_CORES core system"
            exit 1
          fi

          # Calculate core ranges
          AVAILABLE_CORES=$((TOTAL_CORES - RESERVED_CORES))
          RESERVED_START=$AVAILABLE_CORES
          RESERVED_END=$((TOTAL_CORES - 1))

          echo "Reserving cores $RESERVED_START-$RESERVED_END for critical processes"

          # Set CPU isolation
          echo "0-$((AVAILABLE_CORES - 1))" > /sys/fs/cgroup/cpuset/cpuset.cpus

          # Create reserved core group
          mkdir -p /sys/fs/cgroup/cpuset/reserved
          echo "$RESERVED_START-$RESERVED_END" > /sys/fs/cgroup/cpuset/reserved/cpuset.cpus
          echo 0 > /sys/fs/cgroup/cpuset/reserved/cpuset.mems

          echo "CPU core reservation completed"
        '';
      };
    };

    # Memory Optimization Service
    systemd.services.memory-optimizer = mkIf cfg.memoryManagement.enable {
      description = "Memory Optimization Service";
      after = [ "multi-user.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = pkgs.writeShellScript "memory-optimizer" ''
          #!/bin/bash

          echo "Starting memory optimization..."

          ${optionalString cfg.memoryManagement.hugePagesOptimization ''
            # Configure huge pages
            echo madvise > /sys/kernel/mm/transparent_hugepage/enabled
            echo defer > /sys/kernel/mm/transparent_hugepage/defrag
            echo "[$(date)] Huge pages optimization enabled"
          ''}

          ${optionalString cfg.memoryManagement.oomProtection ''
            # Protect critical services from OOM killer
            for service in sshd systemd-logind dbus; do
              if pgrep "$service" >/dev/null; then
                echo -1000 > /proc/$(pgrep "$service")/oom_score_adj 2>/dev/null || true
              fi
            done
            echo "[$(date)] OOM protection applied to critical services"
          ''}

          echo "Memory optimization completed"
        '';
      };
    };

    # Performance monitoring and tuning
    systemd.services.resource-monitor = {
      description = "Resource Usage Monitor";
      after = [ "dynamic-resource-manager.service" ];
      wants = [ "dynamic-resource-manager.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        Restart = "always";
        RestartSec = "60s";
        Environment = [
          "PATH=${lib.makeBinPath (with pkgs; [
            procps # top, free
            gawk # awk
            coreutils # basic utilities
            iproute2 # ss (socket statistics)
            util-linux # uptime
            gnugrep # grep
            gnused # sed
          ])}"
        ];
        ExecStart = pkgs.writeShellScript "resource-monitor" ''
          #!/bin/bash

          METRICS_FILE="/var/lib/resource-manager/metrics.json"
          mkdir -p "$(dirname "$METRICS_FILE")"

          while true; do
            TIMESTAMP=$(date -Iseconds)

            # System metrics
            CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
            LOAD_1M=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
            MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')

            # CPU governor status
            CPU_GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")

            # I/O wait
            IO_WAIT=$(top -bn1 | grep "Cpu(s)" | awk '{print $10}' | sed 's/%wa,//')

            # Network connections
            NETWORK_CONNS=$(ss -tuln | grep LISTEN | wc -l)

            # Create metrics JSON
            cat > "$METRICS_FILE" << EOF
            {
              "timestamp": "$TIMESTAMP",
              "cpu": {
                "usage_percent": "$CPU_USAGE",
                "governor": "$CPU_GOVERNOR",
                "load_1m": "$LOAD_1M",
                "io_wait": "$IO_WAIT"
              },
              "memory": {
                "usage_percent": "$MEMORY_USAGE"
              },
              "network": {
                "connections": $NETWORK_CONNS
              },
              "profile": "${cfg.profile}"
            }
          EOF

            sleep 60
          done
        '';
      };
    };

    # Kernel parameters for resource management
    boot.kernel.sysctl = {
      # CPU scheduling
      "kernel.sched_latency_ns" = mkDefault 6000000; # 6ms
      "kernel.sched_min_granularity_ns" = mkDefault 750000; # 0.75ms
      "kernel.sched_wakeup_granularity_ns" = mkDefault 1000000; # 1ms

      # Memory management
      "vm.swappiness" = mkDefault (
        if cfg.profile == "performance"
        then 1
        else 60
      );
      "vm.vfs_cache_pressure" = mkDefault 100;
      "vm.dirty_background_ratio" = mkDefault 10;
      "vm.dirty_ratio" = mkDefault 20;

      # Note: Network optimization settings moved to networking.performanceTuning module
    };

    # System packages for resource management
    environment.systemPackages = with pkgs;
      [
        util-linux # for ionice, taskset
        bc # for calculations
        procps # for pgrep, top
        inetutils # for network tools
      ]
      ++ optionals cfg.memoryManagement.memoryCompression [
        zram-generator
      ];

    # Create directories
    systemd.tmpfiles.rules = [
      "d /var/lib/resource-manager 0755 root root -"
      "d /var/log/resource-manager 0755 root root -"
    ];

    # Enable memory compression if configured
    zramSwap = mkIf cfg.memoryManagement.memoryCompression {
      enable = true;
      memoryPercent = 25; # Use 25% of RAM for compressed swap
    };
  };
}
