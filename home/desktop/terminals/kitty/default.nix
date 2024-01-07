{ config, pkgs, ... }:

{
  programs.kitty = {
    enable = true;

    #Kitty theme
    theme = "Gruvbox Material Dark Hard";

    #Kitty font
    font = {
      name = "Jetbrains Mono Nerd Font";
      size = 12;
    };
    shellIntegration = {
      enableZshIntegration = true;
      enableBashIntegration = true;
    };

    #Settings
    settings = {
      tab_bar_edge = "top";
      tab_bar_style = "powerline";
      tab_powerline_style = "round";
      tab_activity_symbol = "󰗖 ";
      active_tab_font_style = "bold";
      inactive_tab_font_style = "italics";
      input_delay = 1;
      repaint_delay = 7;
      window_margin_width = 8;
      window_margin_height = 6;
      term = "kitty";
      placement_strategy ="center";

      hide_window_decorations = true;

      background_opacity = "0.56";
      dynamic_background_opacity = true;

      sync_to_monitor = true;
      mouse_hide_wait = 20;
      cursor_shape = "beam";
      cursor_blink_interval = 1;
      cursor_stop_blinking_after = 15;

      #Scrollback pager
      scrollback_lines = 100000;
      scrollback_pager = "kitty-scroll";
    };
  };
}