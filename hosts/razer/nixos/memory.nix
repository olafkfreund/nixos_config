{
  config,
  lib,
  pkgs,
  ...
}: {
  # Memory optimization for 64GB RAM
  boot.kernel.sysctl = {
    "vm.swappiness" = 10; # Reduce swap usage with high RAM
    "vm.vfs_cache_pressure" = 50; # Balance file system cache
    "vm.dirty_ratio" = 10; # Higher threshold before sync
    "vm.dirty_background_ratio" = 5; # Background sync threshold

    # For development workloads
    "vm.max_map_count" = 262144; # For applications that use many memory mappings
  };

  # Create a larger /tmp on tmpfs - using updated option names
  boot.tmp = {
    useTmpfs = true; # Previously boot.tmpOnTmpfs
    tmpfsSize = "16G"; # Previously boot.tmpOnTmpfsSize
  };

  # Optional: zram for better memory management
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = lib.mkDefault 25; # Use 25% of RAM for compressed swap
  };
}
