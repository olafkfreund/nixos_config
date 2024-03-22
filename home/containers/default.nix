{ pkgs, ... }: {

home.packages = with pkgs; [
  distrobox # A minimal Linux distribution.
  ];
}