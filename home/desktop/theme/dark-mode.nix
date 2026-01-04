# Global Dark Mode Configuration
# Works across all desktop environments: COSMIC, GNOME, Hyprland, Sway, etc.
# Focus: GTK dark mode enforcement only
{ lib, ... }:
with lib; {
  # GTK dark mode enforcement - the critical part for dark mode
  gtk = {
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = mkDefault true;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = mkDefault true;
    };
  };

  # Global environment variables for dark mode enforcement
  # These work across ALL desktop environments
  # Note: Theme names, cursor, Qt, and icons are handled by desktop-specific configs
  home.sessionVariables = mkDefault {
    # GTK dark mode enforcement - most important for applications
    GTK_APPLICATION_PREFER_DARK_THEME = "1";

    # Color scheme preference for XDG portals
    GTK_USE_PORTAL = "1";
  };

  # dconf dark mode setting for GNOME/GTK applications
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = mkDefault "prefer-dark";
    };
  };
}
