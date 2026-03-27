{ pkgs, config, lib, ... }:
with lib;
{
  imports = [
    ./qt.nix
    ./dark-mode.nix # Global dark mode configuration for all desktop environments
    ./gtk-cosmic-fix.nix # Auto-patch COSMIC GTK CSS with Gruvbox theme
  ];

  # Only include papirus-icon-theme if GNOME is not enabled (GNOME uses gruvbox-plus-icons)
  home.packages = optionals (!config.desktop.gnome.enable or false) [
    pkgs.papirus-icon-theme
  ];
}
