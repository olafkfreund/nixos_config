{ inputs, lib, config, pkgs, stylix, nix-colors, nixpkgs, ... }: {

imports =[
  nix-colors.homeManagerModules.default
  stylix.homeManagerModules.stylix
  (./home/default.nix)
  (./home/cloud/default.nix)
  (./home/development/default.nix)
  (./home/media/music.nix)
  (./home/media/spice_themes.nix)
  (./home/browsers/default.nix)
];


home.username = "olafkfreund";
home.homeDirectory = "/home/olafkfreund";
home.sessionPath = [
   "$HOME/.local/bin"
];
colorScheme = nix-colors.colorSchemes.gruvbox-material-dark-hard;
home.file = {
    ".config/cmus/rc".text = "colorscheme gruvbox-warm";
  };
home.stateVersion = "24.05";
programs.home-manager.enable = true;
}
