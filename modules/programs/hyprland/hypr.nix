{ inputs, lib, config, pkgs, ... }:{


# Enable hyprland
programs.hyprland = {
  enable = true;
  #enableNvidiaPatches = true;
  xwayland.enable = true;
  };
# programs.hyprland.xwayland = {
#   enable = true;
# };
programs.firefox = {
  enable = true;
  };

}
