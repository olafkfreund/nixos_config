{ config, pkgs, lib, ... }:

{
  # ------------------------------------------
  # XDG Desktop Portal integration
  # ------------------------------------------

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    # wlr.enable = true;
    extraPortals = [ 
      pkgs.xdg-desktop-portal
      pkgs.xdg-desktop-portal-hyprland
    ];
    configPackages = [ 
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal
    ];
  };

}
