{...}: {
  # Development-related modules
  # Only load on hosts that do development work
  imports = [
    ./ai/default.nix
    ./helpers/helpers.nix
    # Note: ./development/default.nix is imported separately in hosts
  ];
}