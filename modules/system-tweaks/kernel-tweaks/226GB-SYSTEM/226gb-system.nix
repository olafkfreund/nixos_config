{
  config,
  lib,
  ...
}: {
  boot.kernel.sysctl = {
    #---------------------------------------------------------------------
    #   Network and memory-related optimizations for 226GB RAM systems
    #---------------------------------------------------------------------

    # System control and recovery
    "kernel.sysrq" = 1; # Enable SysRQ for emergency control when system freezes
    "kernel.panic" = 10; # Reboot after 10 seconds on kernel panic (increased for large memory dumps)

    # Process and thread limits - increased for high-memory workloads
    "kernel.pid_max" = 4194304; # Much higher process limit for memory-intensive workloads
    "kernel.threads-max" = 1048576; # Allow many more threads for large parallel workloads

    # Network buffers and queue sizes - optimized for high bandwidth connections on high-memory systems
    "net.core.netdev_max_backlog" = 100000; # Greatly increased network queue size
    "net.core.rmem_default" = 16777216; # Default socket receive buffer (16MB)
    "net.core.rmem_max" = 536870912; # Max socket receive buffer (512MB)
    "net.core.wmem_default" = 16777216; # Default socket send buffer (16MB)
    "net.core.wmem_max" = 536870912; # Max socket send buffer (512MB)
    "net.core.optmem_max" = 262144; # Maximum ancillary buffer size per socket (256KB)
    "net.core.somaxconn" = 65535; # Maximum socket connection backlog

    # TCP optimizations for high-bandwidth connections with large memory
    "net.ipv4.tcp_rmem" = "8192 16777216 536870912"; # TCP receive buffer (min/default/max) - 8KB/16MB/512MB
    "net.ipv4.tcp_wmem" = "8192 16777216 536870912"; # TCP send buffer (min/default/max) - 8KB/16MB/512MB
    "net.ipv4.tcp_congestion_control" = "bbr"; # Better TCP congestion control algorithm
    "net.ipv4.tcp_fastopen" = 3; # Enable TCP Fast Open
    "net.ipv4.tcp_max_syn_backlog" = 65536; # Handle more connection requests
    "net.ipv4.tcp_max_tw_buckets" = 2000000; # Allow more TIME_WAIT sockets
    "net.ipv4.tcp_mem" = "786432 1048576 1572864"; # Memory reserved for TCP (in 4KB pages): 3GB/4GB/6GB

    # TCP keepalive settings - detect stale connections faster
    "net.ipv4.tcp_keepalive_time" = 300; # Start keepalive after 5 minutes (300 seconds)
    "net.ipv4.tcp_keepalive_probes" = 5; # Number of keepalive probes
    "net.ipv4.tcp_keepalive_intvl" = 30; # Interval between keepalive probes

    # IP fragmentation settings - increased for large memory systems
    "net.ipv4.ipfrag_high_threshold" = 33554432; # 32MB - higher for better performance
    "net.ipv4.ipfrag_low_threshold" = 25165824; # 24MB - prevent excessive fragmentation

    # Memory management - massively scaled for 226GB RAM system
    "vm.dirty_background_bytes" = 4294967296; # 4GB - when background writeback starts
    "vm.dirty_bytes" = 17179869184; # 16GB - when synchronous writeback starts
    "vm.min_free_kbytes" = 1048576; # 1GB minimum free memory
    "vm.swappiness" = 1; # Almost never swap with this much RAM
    "vm.vfs_cache_pressure" = 20; # Much better inode/dentry cache retention (aggressive caching)
    "vm.page-cluster" = 4; # Read-ahead for high-memory system (16 pages)
    "vm.zone_reclaim_mode" = 0; # Disable zone reclaim for NUMA systems

    # NUMA-specific settings for large memory systems (helps with memory locality)
    "vm.numa_stat" = 1; # Enable NUMA statistics
    "vm.numa_balancing" = 1; # Enable automatic NUMA balancing

    # File system and monitoring limits - increased for large memory systems
    "fs.aio-max-nr" = 4194304; # Maximum async I/O requests (4x higher)
    "fs.inotify.max_user_watches" = 1048576; # For development environments and file monitoring (doubled)
    "fs.file-max" = 16777216; # Maximum number of file handles (8x higher)
    "fs.nr_open" = 16777216; # Maximum file descriptors per process

    # Additional performance tweaks
    "kernel.nmi_watchdog" = 0; # Disable NMI watchdog to reduce CPU overhead
    "kernel.randomize_va_space" = 2; # Full ASLR for better security
    "vm.max_map_count" = lib.mkForce 2147483647; # Much larger - for applications using many memory mappings

    # Large memory workload optimizations
    "kernel.sched_migration_cost_ns" = 5000000; # Keep threads on the same CPU longer
    "kernel.sched_autogroup_enabled" = 0; # Disable autogroup for compute-intensive workloads
  };

  # Aggressive transparent hugepage settings for large memory systems
  boot.kernelParams = [
    "transparent_hugepage=always"
    # "default_hugepagesz=2M"
    # "hugepagesz=1G"
    # "hugepages=128" # Allocate 128GB of 1GB hugepages (56% of RAM)
    # "hugepagesz=2M"
    # "hugepages=8192" # Additional 16GB of 2MB hugepages
    # "numa_balancing=enable" # Enable NUMA balancing
    "processor.max_cstate=1" # Reduce latency from CPU sleep states
  ];

  # Adjust scheduler for better throughput on high-memory systems
  services.udev.extraRules = ''
    # Use the BFQ I/O scheduler for rotational disks
    ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"

    # Use the none scheduler for NVMe (rely on internal controller)
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"

    # Increase NVMe queue depth for high-throughput workloads
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/nr_requests}="2048"

    # Increase read-ahead for all block devices
    ACTION=="add|change", SUBSYSTEM=="block", ATTR{queue/read_ahead_kb}="16384"
  '';

  # Runtime CPU performance settings for high-memory workloads
  powerManagement = {
    cpuFreqGovernor = lib.mkDefault "performance";
    powertop.enable = false; # Disable powertop auto-tuning which can reduce performance
  };

  # Adjust resource limits for high-memory workloads
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "soft";
      item = "nofile";
      value = "1048576"; # Doubled from previous config
    }
    {
      domain = "*";
      type = "hard";
      item = "nofile";
      value = "4194304"; # 4x from previous config
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
    {
      domain = "*";
      type = "soft";
      item = "stack";
      value = "65536"; # 64MB stack size
    }
    {
      domain = "*";
      type = "soft";
      item = "nproc";
      value = "unlimited"; # No process limit per user
    }
  ];

  # Create a ramdisk for extremely fast temporary storage
  fileSystems."/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = ["size=64G" "mode=1777" "nosuid" "nodev"]; # 64GB ramdisk
  };
}
