{ inputs
, ...
}: {
  imports = [
    inputs.nix-colors.homeManagerModules.default
    inputs.ags.homeManagerModules.default
    inputs.spicetify-nix.homeManagerModules.default

    ../../home/default.nix
    ./private.nix
  ];

  colorScheme = inputs.nix-colors.colorSchemes.gruvbox-dark-medium;

  home.username = "olafkfreund";
  home.homeDirectory = "/home/olafkfreund";
  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  home.stateVersion = "24.11";
  programs.home-manager.enable = true;
}
