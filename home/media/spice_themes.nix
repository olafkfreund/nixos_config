{
  inputs,
  pkgs,
  lib,
  spicetify-nix,
  ...
}: let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.system};
in {
  # allow spotify to be installed if you don't have unfree enabled already
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "spotify"
    ];

  # import the flake's module for your system
  # imports = [spicetify-nix.homeManagerModule.default];

  # configure spicetify :)
  programs.spicetify = {
    enable = true;
    theme = spicePkgs.themes.text;
    colorScheme = "Gruvbox";

    enabledExtensions = with spicePkgs.extensions; [
      fullAppDisplay
      shuffle # shuffle+ (special characters are sanitized out of ext names)
    ];
  };
}
