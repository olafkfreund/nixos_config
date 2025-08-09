{ lib, ... }: {
  # Memory optimization for 16GB RAM
  boot.kernel.sysctl = {
    "vm.swappiness" = 10; # Reduce swap usage with high RAM
    "vm.vfs_cache_pressure" = 50; # Balance file system cache
    "vm.dirty_ratio" = 5; # Lower threshold for 16GB vs 64GB
    "vm.dirty_background_ratio" = 3; # Background sync threshold

    # For development workloads
    "vm.max_map_count" = 262144; # For applications that use many memory mappings
  };

  # Create a larger /tmp on tmpfs - using updated option names
  boot.tmp = {
    useTmpfs = true; # Previously boot.tmpOnTmpfs
    tmpfsSize = "8G"; # Reduced from 16G for 16GB system
  };

  # Optional: zram for better memory management
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = lib.mkDefault 20; # Use 20% of RAM for compressed swap (16GB system)
  };
}
