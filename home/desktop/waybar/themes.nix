# Waybar Theme System
# Provides consistent theming for Waybar
{
  lib,
  ...
}:
with lib;
let
  # Color scheme definitions matching Hyprland themes
  colorSchemes = {
    gruvbox-dark = {
      name = "Gruvbox Dark";
      colors = {
        bg = "#282828";
        fg = "#ebdbb2";
        bg_dim = "#3c3836";
        border = "#665c54";
        red = "#fb4934";
        green = "#b8bb26";
        yellow = "#fabd2f";
        blue = "#83a598";
        purple = "#d3869b";
        aqua = "#8ec07c";
        orange = "#fe8019";
        gray = "#928374";
      };
    };
  };
  
  # Generate theme configuration
  createWaybarTheme = colorScheme: {
    colors = colorScheme.colors;
    css = {
      window = {
        background = colorScheme.colors.bg;
        color = colorScheme.colors.fg;
      };
      modules = {
        background = "transparent";
        color = colorScheme.colors.fg;
        border = colorScheme.colors.border;
      };
      tooltip = {
        background = colorScheme.colors.bg;
        color = colorScheme.colors.fg;
        border = colorScheme.colors.border;
      };
    };
  };
  
  defaultTheme = "gruvbox-dark";
  
in {
  waybar.colorSchemes = colorSchemes;
  waybar.createTheme = createWaybarTheme;
  waybar.activeTheme = createWaybarTheme colorSchemes.${defaultTheme};
  waybar.getTheme = themeName: 
    if builtins.hasAttr themeName colorSchemes
    then createWaybarTheme colorSchemes.${themeName}
    else createWaybarTheme colorSchemes.${defaultTheme};
}