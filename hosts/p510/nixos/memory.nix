{
  config,
  lib,
  pkgs,
  ...
}: {
  # Memory allocation and optimization
  boot.kernel.sysctl = {
    # Memory management for high-core count Xeon
    "vm.zone_reclaim_mode" = 0; # Disable zone reclaim for better performance
    "vm.vfs_cache_pressure" = 50; # Balance file system cache

    # For ECC memory commonly used with Xeon
    "vm.memory_failure_early_kill" = 1; # Kill processes accessing failed memory
    "vm.memory_failure_recovery" = 1; # Try to recover from memory errors
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
