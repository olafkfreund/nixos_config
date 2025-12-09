_: {
  # Performance optimization modules
  # Only load on hosts that need advanced performance tuning
  imports = [
    ./storage/performance-optimization.nix
    ./storage/garbage-collection.nix
    # Removed modules with root anti-patterns:
    # - ./system/resource-manager.nix (deleted)
    # - ./networking/performance-tuning.nix (deleted)
    # - ./ai/auto-performance-tuner.nix (deleted)
  ];
}
