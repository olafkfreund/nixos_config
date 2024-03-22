{ inputs, lib, config, pkgs, nixpkgs, ... }: {

imports =[
   inputs.nix-colors.homeManagerModules.default
    (../../home/default.nix)
    (./private.nix)
];

#colorScheme = inputs.nix-colors.colorSchemes.gruvbox-dark-medium;

home.username = "olafkfreund";
home.homeDirectory = "/home/olafkfreund";
home.sessionPath = [
   "$HOME/.local/bin"
];

home.stateVersion = "23.11";
programs.home-manager.enable = true;
}
