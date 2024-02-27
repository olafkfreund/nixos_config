{ config, pkgs, lib, ... }:

{
  # ------------------------------------------
  # XDG Desktop Portal integration
  # ------------------------------------------

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;


    # Turn Wayland off
    wlr = {
      enable = true;

    };

    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-kde
      xdg-desktop-portal-wlr
      xdg-desktop-portal-cosmic
    ];

  };

}
