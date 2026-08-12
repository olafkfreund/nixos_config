{ ... }:
{
  imports = [
    ./qt.nix
    ./dark-mode.nix # Global dark mode configuration for all desktop environments
    ./cosmic-theme.nix # COSMIC accent colour from central base16 scheme
  ];

  # No icon package here. modules/desktop/stylix-theme.nix installs
  # papirus-icon-theme with green folders through stylix.icons, for every
  # desktop. Adding the plain build alongside it collides on the shared
  # share/icons/Papirus* paths; the old GNOME/non-GNOME split existed only
  # because GNOME used to get a different icon set instead.
}
