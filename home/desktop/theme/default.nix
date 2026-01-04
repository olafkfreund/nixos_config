{ pkgs, config, lib, ... }:
with lib;
{
  imports = [
    ./qt.nix
    ./dark-mode.nix # Global dark mode configuration for all desktop environments
  ];

  home.packages = with pkgs; [
    wallust
    # Only include papirus-icon-theme if GNOME is not enabled (GNOME uses gruvbox-plus-icons)
  ] ++ optionals (!config.desktop.gnome.enable or false) [
    papirus-icon-theme
  ];
}
