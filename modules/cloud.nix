_: {
  # Cloud tools and services
  # Only load on hosts that need cloud integration
  imports = [
    ./cloud/default.nix
  ];
}
