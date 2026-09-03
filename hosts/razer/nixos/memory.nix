{ lib, ... }: {
  # Memory optimization for 64GB RAM
  boot.kernel.sysctl = {
    "vm.swappiness" = 10; # Reduce swap usage with high RAM
    "vm.vfs_cache_pressure" = 50; # Balance file system cache
    "vm.dirty_ratio" = 10; # Higher threshold before sync
    "vm.dirty_background_ratio" = 5; # Background sync threshold

    # For development workloads
    "vm.max_map_count" = 262144; # For applications that use many memory mappings
  };

  # /tmp on disk, not in RAM.
  #
  # This was a 16G tmpfs, which is a quarter of this laptop's memory handed to
  # a build directory -- and nix builds in $TMPDIR, so a large rebuild both
  # fills it and eats the RAM it was meant to leave free. p620 hit exactly that
  # twice (#1635): the failure reads as a full disk while `df /` reports
  # hundreds of gigabytes free, because the thing that filled is RAM.
  #
  # / is a 938G NVMe with 460G+ free. cleanOnBoot restores the clear-on-restart
  # behaviour tmpfs gave for free -- it was off here because tmpfs made it
  # redundant, and on disk it is not.
  #
  # razer builds through p620 (`just deploy-via-p620 razer`) so it rarely
  # unpacks the big derivations itself, which is why this never bit here. That
  # is a habit, not a guarantee.
  boot.tmp = {
    useTmpfs = false;
    cleanOnBoot = true;
  };

  # Optional: zram for better memory management
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = lib.mkDefault 25; # Use 25% of RAM for compressed swap
  };
}
