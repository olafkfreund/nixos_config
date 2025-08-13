{ inputs, ... }: {
  # Common imports for all user configurations
  imports = [
    inputs.nix-colors.homeManagerModules.default
    inputs.ags.homeManagerModules.default
    inputs.spicetify-nix.homeManagerModules.default
    # inputs.walker.homeManagerModules.default # Temporarily disabled - broken commit

    # Internal modules
    ./base-home.nix
    ./features.nix
    ./features-impl.nix

    # Development environment modules
    ../../home/development/default.nix
  ];
}
