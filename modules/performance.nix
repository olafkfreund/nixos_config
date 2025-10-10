_: {
  # Performance optimization modules
  # Only load on hosts that need advanced performance tuning
  imports = [
    ./system/resource-manager.nix
    ./networking/performance-tuning.nix
    ./storage/performance-optimization.nix
    # ./ai/auto-performance-tuner.nix  # Removed - non-functional AI service consuming resources
  ];
}
