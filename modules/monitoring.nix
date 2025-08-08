_: {
  # Monitoring and observability modules
  # Only load on hosts that need monitoring
  imports = [
    ./packages/default.nix # Shared dependency management for monitoring
    ./monitoring/default.nix
    ./monitoring/promtail.nix
  ];
}
