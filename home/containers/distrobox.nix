{ pkgs, pkgs-stable, ... }: {

home.packages = with pkgs; [
  distrobox # A minimal Linux distribution.
  ];
}