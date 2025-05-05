{
  config,
  lib,
  ...
}: {
  boot.kernel.sysctl = {
    #---------------------------------------------------------------------
    #   Network and memory-related optimizations for 64GB RAM systems
    #---------------------------------------------------------------------

    # System control and recovery
    "kernel.sysrq" = 1; # Enable SysRQ for emergency control when system freezes
    "kernel.panic" = 5; # Reboot after 5 seconds on kernel panic

    # Process and thread limits
    "kernel.pid_max" = 131072; # Allow more processes/threads (good for development workloads)

    # Network buffers and queue sizes - optimized for high bandwidth connections
    "net.core.netdev_max_backlog" = 30000; # Increase network queue size to prevent packet loss
    "net.core.rmem_default" = 1048576; # Default socket receive buffer (1MB)
    "net.core.rmem_max" = 134217728; # Max socket receive buffer (128MB)
    "net.core.wmem_default" = 1048576; # Default socket send buffer (1MB)
    "net.core.wmem_max" = 134217728; # Max socket send buffer (128MB)
    "net.core.optmem_max" = 65536; # Maximum ancillary buffer size per socket

    # TCP optimizations for high-bandwidth connections
    "net.ipv4.tcp_rmem" = "4096 1048576 33554432"; # TCP receive buffer (min/default/max)
    "net.ipv4.tcp_wmem" = "4096 1048576 33554432"; # TCP send buffer (min/default/max)
    "net.ipv4.tcp_congestion_control" = "bbr"; # Better TCP congestion control algorithm
    "net.ipv4.tcp_fastopen" = 3; # Enable TCP Fast Open

    # TCP keepalive settings - detect stale connections faster
    "net.ipv4.tcp_keepalive_time" = 300; # Start keepalive after 5 minutes (300 seconds)
    "net.ipv4.tcp_keepalive_probes" = 5; # Number of keepalive probes
    "net.ipv4.tcp_keepalive_intvl" = 30; # Interval between keepalive probes

    # IP fragmentation settings
    "net.ipv4.ipfrag_high_threshold" = 8388608; # 8MB - higher for better performance
    "net.ipv4.ipfrag_low_threshold" = 6291456; # 6MB - prevent excessive fragmentation

    # Memory management - optimized for large RAM systems
    "vm.dirty_background_bytes" = 268435456; # 256MB - when background writeback starts
    "vm.dirty_bytes" = 536870912; # 512MB - when synchronous writeback starts
    "vm.min_free_kbytes" = 262144; # 256MB minimum free memory
    "vm.swappiness" = 5; # Strongly prefer keeping data in RAM
    "vm.vfs_cache_pressure" = 50; # Better inode/dentry cache retention
    "vm.page-cluster" = 3; # Read-ahead for SSD performance

    # File system and monitoring limits
    "fs.aio-max-nr" = 1048576; # Maximum async I/O requests
    "fs.inotify.max_user_watches" = 524288; # For development environments and file monitoring
    "fs.file-max" = 2097152; # Maximum number of file handles

    # Additional performance tweaks
    "kernel.nmi_watchdog" = 0; # Disable NMI watchdog to reduce CPU overhead
    "kernel.randomize_va_space" = 2; # Full ASLR for better security
    "vm.max_map_count" = 1048576; # Needed for applications using many memory mappings
  };

  # More aggressive transparent hugepage settings
  boot.kernelParams = [
    "transparent_hugepage=always"
    "default_hugepagesz=2M"
    "hugepagesz=1G"
    "hugepages=4" # Allocate four 1GB hugepages
  ];

  # Adjust scheduler for better throughput
  services.udev.extraRules = ''
    # Use the BFQ I/O scheduler for rotational disks
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"

    # Use the none scheduler for NVMe (rely on internal controller)
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
  '';

  # Runtime CPU performance settings
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  # Adjust resource limits for the system
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "soft";
      item = "nofile";
      value = "524288";
    }
    {
      domain = "*";
      type = "hard";
      item = "nofile";
      value = "1048576";
    }
    {
      domain = "*";
      type = "soft";
      item = "memlock";
      value = "unlimited";
    }
    {
      domain = "*";
      type = "hard";
      item = "memlock";
      value = "unlimited";
    }
  ];
}
