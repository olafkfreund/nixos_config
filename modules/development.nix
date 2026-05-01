_: {
  # Development-related modules
  # Only load on hosts that do development work
  imports = [
    ./ai/default.nix
    ./helpers
    # Note: ./development/default.nix is imported separately in hosts
  ];
}
