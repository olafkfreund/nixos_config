{ ... }: {
  # Common imports for all user configurations
  imports = [
    # Note: nix-colors, spicetify-nix modules disabled due to upstream issues

    # Internal modules
    ./base-home.nix
    ./features.nix
    ./features-impl.nix

    # Desktop modules (options always available, enabled via features)
    ../../home/desktop/default.nix

    # Development environment modules
    ../../home/development/default.nix
  ];
}
