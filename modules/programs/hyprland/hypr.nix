{ inputs, lib, config, pkgs, ... }:{


# Enable hyprland
programs.hyprland = {
  enable = true;
  # enableNvidiaPatches = true;
  };
# programs.hyprland.xwayland = {
#   enable = true;
# };
}
