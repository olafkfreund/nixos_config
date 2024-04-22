{ config, pkgs, lib, ... }:

{
  # ------------------------------------------
  # XDG Desktop Portal integration
  # ------------------------------------------

  xdg.portal = {
    enable = true;
    # wlr.enable = true;
    # gtk portal needed to make gtk apps happy
    # extraPortals = [ 
    #   pkgs.xdg-desktop-portal
    #   pkgs.xdg-desktop-portal-wlr
    # ];
    # configPackages = [ 
    #   pkgs.xdg-desktop-portal-hyprland
    #   pkgs.xdg-desktop-portal-wlr
    #   pkgs.xdg-desktop-portal
      
    # ];

  };

}
