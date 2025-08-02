{...}: {
  # Monitoring and observability modules
  # Only load on hosts that need monitoring
  imports = [
    ./monitoring/default.nix
  ];
}