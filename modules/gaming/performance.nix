{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.gaming.performance = {
    enable = lib.mkEnableOption "gaming performance optimizations";

    gamemode = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable GameMode for performance optimization";
    };

    kernel = {
      scheduler = lib.mkOption {
        type = lib.types.enum ["default" "performance" "gaming"];
        default = "default";
        description = "Kernel scheduler optimization";
      };

      preemption = lib.mkOption {
        type = lib.types.enum ["desktop" "low-latency" "server"];
        default = "desktop";
        description = "Kernel preemption model";
      };
    };

    cpu = {
      governor = lib.mkOption {
        type = lib.types.enum ["ondemand" "performance" "powersave" "conservative"];
        default = "performance";
        description = "CPU frequency governor for gaming";
      };
    };

    memory = {
      hugepages = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable transparent huge pages";
      };

      swappiness = lib.mkOption {
        type = lib.types.int;
        default = 10;
        description = "VM swappiness value (0-100)";
      };
    };

    networking = {
      tcp_optimization = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable TCP optimizations for gaming";
      };
    };
  };

  config = lib.mkIf config.modules.gaming.performance.enable {
    # GameMode
    programs.gamemode = lib.mkIf config.modules.gaming.performance.gamemode {
      enable = true;
      settings = {
        general = {
          renice = 10;
        };
        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          gpu_device = 0;
        };
      };
    };

    # CPU frequency scaling
    powerManagement = {
      cpuFreqGovernor =
        lib.mkIf (config.modules.gaming.performance.cpu.governor != "ondemand")
        config.modules.gaming.performance.cpu.governor;
    };

    # Kernel parameters for gaming
    boot.kernel.sysctl = lib.mkMerge [
      # Memory management
      (lib.mkIf config.modules.gaming.performance.memory.hugepages {
        "vm.nr_hugepages" = 1024;
      })
      {
        "vm.swappiness" = config.modules.gaming.performance.memory.swappiness;
        "vm.vfs_cache_pressure" = 50;
        "vm.dirty_ratio" = 15;
        "vm.dirty_background_ratio" = 5;
      }

      # Network optimizations
      (lib.mkIf config.modules.gaming.performance.networking.tcp_optimization {
        "net.core.rmem_default" = 262144;
        "net.core.rmem_max" = 16777216;
        "net.core.wmem_default" = 262144;
        "net.core.wmem_max" = 16777216;
        "net.ipv4.tcp_rmem" = "4096 87380 16777216";
        "net.ipv4.tcp_wmem" = "4096 65536 16777216";
        "net.ipv4.tcp_congestion_control" = "bbr";
        "net.core.default_qdisc" = "fq";
      })
    ];

    # Performance monitoring tools
    environment.systemPackages = with pkgs; [
      htop
      iotop
      nethogs
      iftop
      lm_sensors
      stress-ng
    ];

    # Enable performance counters
    boot.kernelParams =
      [
        "mitigations=off" # Disable CPU mitigations for performance (less secure)
      ]
      ++ lib.optionals (config.modules.gaming.performance.kernel.scheduler == "performance") [
        "rcu_nocbs=0-7" # Offload RCU callbacks
      ];
  };
}
