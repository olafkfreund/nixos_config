{ pkgs, ... }:
let

  pkgsUnstable = import <nixpkgs-unstable> {};

in{
home.packages = with pkgs; [
  slack
  teams-for-linux
  thunderbird
  discord
  betterbird
  obsidian
  zathura
  dbeaver
  postgresql
  caprine-bin
  element-desktop
  imagemagick
  fractal
  telegram-desktop
  ];
}
