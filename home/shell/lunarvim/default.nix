{ pkgs, pkgs-stable, ...}: {
  home.packages = with pkgs-stable; [
    lunarvim
  ];
}
