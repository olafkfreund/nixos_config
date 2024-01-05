{ config, lib, pkgs, ... }:
{
  imports = [ ../waybar/sway_waybar.nix ];
  programs = {
    dconf.enable = true;
  };
  security.pam.services.swaylock = { };
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk pkgs.xdg-desktop-portal-wlr ];
  };

}