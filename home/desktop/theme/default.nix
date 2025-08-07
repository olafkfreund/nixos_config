{ pkgs, ... }: {
  imports = [
    ./qt.nix
  ];

  home.packages = with pkgs; [
    wallust
    papirus-icon-theme
  ];
}
