{ inputs, lib, config, pkgs, nixpkgs, ... }: {

imports =[
   inputs.nix-colors.homeManagerModules.default
    (../../home/default.nix)
    (../../home/cloud/default.nix)
    (../../home/development/default.nix)
    (../../home/media/music.nix)
    (../../home/media/spice_themes.nix)
    (../../home/browsers/default.nix)
];

colorScheme = inputs.nix-colors.colorSchemes.gruvbox-dark-medium;

home.username = "olafkfreund";
home.homeDirectory = "/home/olafkfreund";
home.sessionPath = [
   "$HOME/.local/bin"
];

home.stateVersion = "23.11";
programs.home-manager.enable = true;
}
