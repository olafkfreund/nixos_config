{ lib
, pkgs
, ...
}: {
  # Memory allocation and NUMA optimization
  boot.kernel.sysctl = {
    # Huge pages configuration (reduced from 8GB to 2GB for desktop responsiveness)
    # Can be increased when running specific AI/ML workloads
    "vm.nr_hugepages" = 1024; # 1024 * 2MB = 2 GB
    "vm.hugetlb_shm_group" = 0; # Allow all users to use huge pages
    "vm.max_map_count" = 1048576;

    # Memory management for high-core count Threadripper
    "vm.swappiness" = 10;
    "vm.dirty_ratio" = 3;
    "vm.dirty_background_ratio" = 2;
    "vm.vfs_cache_pressure" = 50;

    # NUMA optimizations (enabled for Threadripper PRO performance)
    # NOTE: These settings are overridden in cpu.nix for better NUMA performance
    # "vm.zone_reclaim_mode" = 1;  # Configured in cpu.nix
    # "kernel.numa_balancing" = 1; # Configured in cpu.nix

    # Transparent Huge Pages (THP) - allow applications to request THP automatically
    "vm.transparent_hugepage" = "madvise";

    # Network performance optimizations for NFS and media streaming
    # Override AI module settings with higher performance values
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
  };

  # zram for improved memory performance
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25; # Use 25% of RAM for compressed swap
  };

  # Install memory assessment tools
  environment.systemPackages = with pkgs; [
    memtest86plus
    nmon
    htop
    inxi
  ];
}
