{ pkgs, config, lib, ... }:
let inherit (lib) optionals; in
{
  imports = [
    ./qt.nix
    ./dark-mode.nix # Global dark mode configuration for all desktop environments
    ./cosmic-theme.nix # COSMIC accent colour from central base16 scheme
  ];

  # Only include papirus-icon-theme if GNOME is not enabled (GNOME uses gruvbox-plus-icons)
  home.packages = optionals (!config.desktop.gnome.enable or false) [
    pkgs.papirus-icon-theme
  ];
}
