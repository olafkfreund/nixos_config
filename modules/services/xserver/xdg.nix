# xdg.nix
#
# Set up and enforce XDG compliance. Other modules will take care of their own,
# but this takes care of the general cases.

{ config, pkgs, home-manager, ... }:
{
  xdg.mime.enable = true;
  xdg.autostart.enable = true;

}
