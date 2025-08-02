{...}: {
  # Email-related modules
  # Only load on hosts that need email functionality
  imports = [
    ./email/default.nix
  ];
}