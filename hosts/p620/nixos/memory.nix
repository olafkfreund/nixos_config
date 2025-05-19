{
  config,
  lib,
  pkgs,
  ...
}: {
  # Memory allocation and NUMA optimization
  boot.kernel.sysctl = {
    # Existing settings
    "vm.nr_hugepages" = 1024;
    "vm.max_map_count" = 1048576;

    # Memory management for high-core count Threadripper
    "vm.swappiness" = 10;
    "vm.dirty_ratio" = 3;
    "vm.dirty_background_ratio" = 2;
    "vm.vfs_cache_pressure" = 50;

    # NUMA optimizations
    "vm.zone_reclaim_mode" = 0;
    "kernel.numa_balancing" = 0;
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
