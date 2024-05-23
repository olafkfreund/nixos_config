{ inputs, lib, config, pkgs, nixpkgs, ... }: {

imports =[
   inputs.nix-colors.homeManagerModules.default
    (../../home/default.nix)
    (./private.nix)
];

colorScheme = inputs.nix-colors.colorSchemes.gruvbox-dark-hard;

home.username = "olafkfreund";
home.homeDirectory = "/home/olafkfreund";
home.sessionPath = [
   "$HOME/.local/bin"
];

home.stateVersion = "24.05";
programs.home-manager.enable = true;
}
