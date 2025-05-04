{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.desktop.zathura;

  # Gruvbox theme colors
  theme = {
    bg = "#1d2021";
    bg1 = "#3c3836";
    bg2 = "#504945";
    fg = "#ebdbb2";
    gray = "#928374";
    red = "#fb4934";
    green = "#b8bb26";
    yellow = "#fabd2f";
    blue = "#83a598";
    orange = "#fe8019";
  };
in {
  options.desktop.zathura = {
    enable = mkEnableOption "zathura document viewer";
  };

  config = mkIf cfg.enable {
    programs.zathura = {
      enable = true;
      extraConfig = ''
        # Font settings
        set font "JetBrainsMono 10"

        # Key mappings
        map D set "first-page-column 1:1"        # Single page view
        map <C-d> set "first-page-column 1:2"    # Double page view

        # System integration
        set selection-clipboard clipboard

        # Notification colors
        set notification-error-bg       "${theme.bg}"
        set notification-error-fg       "${theme.red}"
        set notification-warning-bg     "${theme.bg}"
        set notification-warning-fg     "${theme.yellow}"
        set notification-bg             "${theme.bg}"
        set notification-fg             "${theme.green}"

        # Completion colors
        set completion-bg               "${theme.bg2}"
        set completion-fg               "${theme.fg}"
        set completion-group-bg         "${theme.bg1}"
        set completion-group-fg         "${theme.gray}"
        set completion-highlight-bg     "${theme.blue}"
        set completion-highlight-fg     "${theme.bg2}"

        # Index mode colors
        set index-bg                    "${theme.bg2}"
        set index-fg                    "${theme.fg}"
        set index-active-bg             "${theme.blue}"
        set index-active-fg             "${theme.bg2}"

        # UI element colors
        set inputbar-bg                 "${theme.bg}"
        set inputbar-fg                 "${theme.fg}"
        set statusbar-bg                "${theme.bg2}"
        set statusbar-fg                "${theme.fg}"
        set highlight-color             "${theme.yellow}"
        set highlight-active-color      "${theme.orange}"
        set default-bg                  "${theme.bg}"
        set default-fg                  "${theme.fg}"

        # Loading visualization
        set render-loading              true
        set render-loading-bg           "${theme.bg}"
        set render-loading-fg           "${theme.fg}"

        # Document recoloring for dark mode
        set recolor                     true
        set recolor-lightcolor          "${theme.bg}"
        set recolor-darkcolor           "${theme.fg}"
        # set recolor-keephue             true      # Uncomment to keep original color's hue
      '';
    };
  };
}
