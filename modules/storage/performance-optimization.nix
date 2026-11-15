# Storage Performance Optimization Module
{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkOption mkIf mkEnableOption mkDefault mkMerge types;
  cfg = config.storage.performanceOptimization;
in
{
  imports = [
    (lib.mkRemovedOptionModule [ "storage" "performanceOptimization" "ioSchedulerOptimization" ]
      "never ran: the optimizer unit had no PATH (#2935)")
    (lib.mkRemovedOptionModule [ "storage" "performanceOptimization" "filesystemOptimization" "readaheadOptimization" ]
      "never ran: the optimizer unit had no PATH (#2935)")
    (lib.mkRemovedOptionModule [ "storage" "performanceOptimization" "nvmeOptimization" ]
      "never ran: the optimizer unit had no PATH (#2935)")
    (lib.mkRemovedOptionModule [ "storage" "performanceOptimization" "diskCacheOptimization" ]
      "never ran: the optimizer unit had no PATH (#2935)")
  ];

  options.storage.performanceOptimization = {
    enable = mkEnableOption "Enable storage performance optimization";

    profile = mkOption {
      type = types.enum [ "performance" "balanced" "reliability" ];
      default = "balanced";
      description = "Storage optimization profile";
    };

    filesystemOptimization = {
      enable = mkEnableOption "Enable filesystem optimization";

      cacheOptimization = mkOption {
        type = types.bool;
        default = true;
        description = "Enable filesystem cache optimization";
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

    boot.kernel.sysctl = mkMerge [
      {
        "vm.dirty_writeback_centisecs" = { performance = 1500; balanced = 1500; reliability = 500; }.${cfg.profile};
        "vm.dirty_expire_centisecs" = mkDefault { performance = 500; balanced = 3000; reliability = 1000; }.${cfg.profile};
        "vm.page-cluster" = 3;
      }
      (mkIf (cfg.filesystemOptimization.enable && cfg.filesystemOptimization.cacheOptimization) {
        "vm.dirty_background_ratio" = { performance = 5; balanced = 10; reliability = 5; }.${cfg.profile};
        "vm.dirty_ratio" = { performance = 10; balanced = 20; reliability = 10; }.${cfg.profile};
        "vm.dirty_bytes" = null; # nixarchy sets these; null keeps the ratios the only owner (#2935)
        "vm.dirty_background_bytes" = null;
      })
    ];

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
