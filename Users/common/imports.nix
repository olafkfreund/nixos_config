{
  inputs,
  lib,
  ...
}: {
  # Common imports for all user configurations
  imports = [
    inputs.nix-colors.homeManagerModules.default
    inputs.ags.homeManagerModules.default
    inputs.spicetify-nix.homeManagerModules.default
    inputs.walker.homeManagerModules.default

    # Internal modules
    ./base-home.nix
    ./features.nix
    # Temporarily disabled for isolated enhanced desktop test
    # ./features-impl.nix
  ];
}
