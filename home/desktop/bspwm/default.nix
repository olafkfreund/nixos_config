{ config, lib, pkgs, user, ... }:
{
  imports = [ ../polybar ];
  services.xserver = {
    enable = true;
    displayManager = {
      startx.enable = true;
    };
  };
  programs = {
    dconf.enable = true;
  };
  environment.systemPackages = with pkgs; [
    pamixer
    i3lock-fancy
  ];
}