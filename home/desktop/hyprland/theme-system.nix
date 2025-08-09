# Hyprland Centralized Theming System
# Provides consistent theming across all Hyprland components
{ lib, ... }:
with lib; let
  # Color scheme definitions
  colorSchemes = {
    gruvbox-dark = {
      name = "Gruvbox Dark";
      colors = {
        bg0 = "1d2021";
        bg1 = "3c3836";
        bg2 = "504945";
        bg3 = "665c54";
        fg0 = "fbf1c7";
        fg1 = "ebdbb2";
        fg2 = "d5c4a1";
        fg3 = "bdae93";
        red = "cc241d";
        green = "98971a";
        yellow = "d79921";
        blue = "458588";
        purple = "b16286";
        aqua = "689d6a";
        orange = "d65d0e";
      };
      opacity = {
        active = 1.0;
        inactive = 0.95;
        floating = 0.98;
        fullscreen = 1.0;
      };
    };
  };

  # Theme configuration generator
  createThemeConfig = colorScheme: {
    hyprland = {
      general = {
        "col.active_border" = "rgb(${colorScheme.colors.blue})";
        "col.inactive_border" = "rgb(${colorScheme.colors.bg2})";
      };
      decoration = {
        active_opacity = colorScheme.opacity.active;
        inactive_opacity = colorScheme.opacity.inactive;
        fullscreen_opacity = colorScheme.opacity.fullscreen;
        shadow.color = "rgb(${colorScheme.colors.bg0})";
      };
    };
  };

  defaultTheme = "gruvbox-dark";
in
{
  hyprland.colorSchemes = colorSchemes;
  hyprland.createThemeConfig = createThemeConfig;
  hyprland.activeTheme = createThemeConfig colorSchemes.${defaultTheme};
  hyprland.getTheme = themeName:
    if builtins.hasAttr themeName colorSchemes
    then createThemeConfig colorSchemes.${themeName}
    else createThemeConfig colorSchemes.${defaultTheme};
}
