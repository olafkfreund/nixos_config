{ config
, lib
, ...
}:
with lib;
# SSD performance and longevity optimization  
# Balances performance with write reduction to extend SSD lifespan
{
  boot.kernel.sysctl = {
    #---------------------------------------------------------------------
    #   SSD-optimized memory and I/O parameters
    #---------------------------------------------------------------------

    # Memory dirty ratio settings - more conservative for SSD longevity
    "vm.dirty_background_ratio" = 5; # Start background writeback at 5% dirty memory (reduced from 40%)
    "vm.dirty_ratio" = 10; # Force synchronous I/O at 10% dirty memory (reduced from 80%)

    # Time-based writeback settings - more frequent for better responsiveness
    "vm.dirty_expire_centisecs" = 1500; # Data becomes eligible for writeback after 15 seconds (reduced from 30s)
    "vm.dirty_writeback_centisecs" = 300; # Background writeback every 3 seconds

    # Disable dirty time accounting (correct setting)
    "vm.dirty_time" = 0;

    # I/O scheduler settings for SSDs
    "vm.vfs_cache_pressure" = 50; # Reduce inode/dentry cache pressure (default: 100)
    "vm.swappiness" = 10; # Reduce swappiness for better performance

    # Increase readahead for better sequential read performance
    "vm.page-cluster" = 1; # Use smaller pages for readahead (good for random I/O)
  };

  #---------------------------------------------------------------------
  # TRIM configuration - essential for SSD health and performance
  #---------------------------------------------------------------------
  services.fstrim = {
    enable = true;
    interval = "weekly"; # Run TRIM weekly (default, but explicitly set)
  };

  #---------------------------------------------------------------------
  # Mount options for SSDs
  #---------------------------------------------------------------------
  fileSystems = mkIf (config.fileSystems ? "/") {
    "/" = {
      options = mkBefore [
        "noatime" # Disable access time updates
        "nodiratime" # Disable directory access time updates
        "discard" # Enable continuous TRIM (use with caution)
      ];
    };
  };

  #---------------------------------------------------------------------
  # I/O Scheduler settings
  #---------------------------------------------------------------------
  services.udev.extraRules = ''
    # Set I/O scheduler to 'none' for NVMe SSDs
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"

    # Set I/O scheduler to 'mq-deadline' for SATA SSDs
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
  '';
}
