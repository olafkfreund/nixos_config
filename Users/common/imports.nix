{ spicetify-nix, ... }: {
  # Common imports for all user configurations
  imports = [
    spicetify-nix.homeManagerModules.default

    # Internal modules
    ./base-home.nix
    ./features.nix
    ./features-impl.nix

    # Desktop modules (options always available, enabled via features)
    ../../home/desktop/default.nix

    # Development environment modules
    ../../home/development/default.nix

    # Syncthing .stignore — managed declaratively for every host
    # (p510 doesn't import home/default.nix via profile.nix, so this
    # is the common bind site that reaches all three host_home.nix files).
    ../../home/syncthing-stignore.nix
  ];
}
