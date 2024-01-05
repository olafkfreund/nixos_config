{ config, lib, pkgs, ... }:


services = {
  picom.enable = true;
  redshift.enable = true;
  xserver = {
    windowManager.bspwm.enable = true;
};

environment.systemPackages = with pkgs; [
  lightdm
  dunst
  libnotify
  (polybar.override {
    pulseSupport = true;
    nlSupport = true;
  })
];

