{ lib
, pkgs
, ...
}: {
  # Memory allocation and optimization
  boot.kernel.sysctl = {
    # Memory management for high-core count Xeon
    "vm.zone_reclaim_mode" = 0; # Disable zone reclaim for better performance
    "vm.vfs_cache_pressure" = 50; # Balance file system cache
    "vm.swappiness" = 10; # Reduce swap usage for media server performance
    "vm.dirty_ratio" = 15; # Allow more dirty pages for better throughput
    "vm.dirty_background_ratio" = 5; # Background flush for large media files
    "vm.max_map_count" = 1048576; # Support for memory-mapped files

    # For ECC memory commonly used with Xeon
    "vm.memory_failure_early_kill" = 1; # Kill processes accessing failed memory
    "vm.memory_failure_recovery" = 1; # Try to recover from memory errors

    # Network performance optimizations for NFS server and media streaming
    # Override AI module settings with higher performance values for media server
    "net.core.rmem_max" = lib.mkForce 134217728; # 128MB receive buffer
    "net.core.wmem_max" = lib.mkForce 134217728; # 128MB send buffer  
    "net.core.rmem_default" = 262144; # 256KB default receive
    "net.core.wmem_default" = 262144; # 256KB default send
    "net.core.netdev_max_backlog" = lib.mkForce 5000; # Increased queue size
    "net.ipv4.tcp_rmem" = "4096 262144 134217728"; # TCP receive memory
    "net.ipv4.tcp_wmem" = "4096 262144 134217728"; # TCP send memory
    "net.ipv4.tcp_congestion_control" = "bbr"; # Better congestion control
    "net.ipv4.tcp_window_scaling" = 1; # Enable window scaling
    "net.ipv4.tcp_timestamps" = lib.mkForce 1; # Enable timestamps for RTT
    "net.ipv4.tcp_sack" = lib.mkForce 1; # Selective acknowledgment
    "net.core.default_qdisc" = "fq"; # Fair queuing scheduler

    # File system performance for media files
    "fs.file-max" = 2097152; # Increase max open files
    "fs.nr_open" = 1048576; # Per-process file descriptor limit
  };

  # For better memory performance with many cores
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5; # Percentage
    freeSwapThreshold = 10; # Percentage
  };

  # Install memory management tools
  environment.systemPackages = with pkgs; [
    memtest86plus
    numactl # NUMA control utility
    dmidecode # For memory hardware details
  ];
}
