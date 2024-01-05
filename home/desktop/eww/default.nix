{ inputs, lib, config, pkgs, ... }: {

home.packages = with pkgs; [
 eww
 eww-wayland
  ];
}