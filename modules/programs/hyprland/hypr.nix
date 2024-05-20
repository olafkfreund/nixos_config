{ inputs, lib, config, pkgs-stable, pkgs, ... }:{


# Enable hyprland
programs.hyprland = {
  enable = true;
  package = pkgs.hyprland;
  #enableNvidiaPatches = true;
  xwayland.enable = true;
  };
# programs.hyprland.xwayland = {
#   enable = true;
# };
programs.firefox = {
  enable = true;
  };
programs.wshowkeys = {
  enable = true;
  };
programs.nix-ld = {
  enable = true;
  };
}
