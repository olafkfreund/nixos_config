{
  config,
  pks,
  pkgs-stable,
  ...
}: {
  xdg.mimeApps = {
    associations.added = {
      "x-scheme-handler/terminal" = "kitty.desktop";
    };
    defaultApplications = {
      "x-scheme-handler/terminal" = "kitty.desktop";
    };
  };

  programs.kitty = {
    enable = true;
    package = pkgs-stable.kitty;

    #Kitty theme
    theme = "Gruvbox Material Dark Hard";

    #Kitty font
    # font = {
    #   name = "Jetbrains Mono Nerd Font";
    #   size = 12;
    # };
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
      placement_strategy = "center";

      hide_window_decorations = true;

      # background_opacity = "0.85";
      dynamic_background_opacity = true;
      copy_on_select = true;
      sync_to_monitor = true;
      mouse_hide_wait = 20;
      cursor_shape = "beam";
      cursor_blink_interval = 1;
      cursor_stop_blinking_after = 15;

      #Scrollback pager
      scrollback_lines = 100000;
      scrollback_pager = "kitty-scroll";
      #include ./kitty-themes/gruvbox_dark.conf
    };
    extraConfig = ''
      foreground #${config.colorScheme.palette.base05}
      background #${config.colorScheme.palette.base00}
      color0  #${config.colorScheme.palette.base03}
      color1  #${config.colorScheme.palette.base08}
      color2  #${config.colorScheme.palette.base0B}
      color3  #${config.colorScheme.palette.base09}
      color4  #${config.colorScheme.palette.base0D}
      color5  #${config.colorScheme.palette.base0E}
      color6  #${config.colorScheme.palette.base0C}
      color7  #${config.colorScheme.palette.base06}
      color8  #${config.colorScheme.palette.base04}
      color9  #${config.colorScheme.palette.base08}
      color10 #${config.colorScheme.palette.base0B}
      color11 #${config.colorScheme.palette.base0A}
      color12 #${config.colorScheme.palette.base0C}
      color13 #${config.colorScheme.palette.base0E}
      color14 #${config.colorScheme.palette.base0C}
      color15 #${config.colorScheme.palette.base07}
      color16 #${config.colorScheme.palette.base00}
      color17 #${config.colorScheme.palette.base0F}
      color18 #${config.colorScheme.palette.base0B}
      color19 #${config.colorScheme.palette.base09}
      color20 #${config.colorScheme.palette.base0D}
      color21 #${config.colorScheme.palette.base0E}
      color22 #${config.colorScheme.palette.base0C}
      color23 #${config.colorScheme.palette.base06}
      cursor  #${config.colorScheme.palette.base07}
      cursor_text_color #${config.colorScheme.palette.base00}
      selection_foreground #${config.colorScheme.palette.base01}
      selection_background #${config.colorScheme.palette.base0D}
      url_color #${config.colorScheme.palette.base0C}
      active_border_color #${config.colorScheme.palette.base04}
      inactive_border_color #${config.colorScheme.palette.base00}
      bell_border_color #${config.colorScheme.palette.base03}
      tab_bar_style fade
      tab_fade 1
      active_tab_foreground   #${config.colorScheme.palette.base04}
      active_tab_background   #${config.colorScheme.palette.base00}
      active_tab_font_style   bold
      inactive_tab_foreground #${config.colorScheme.palette.base07}
      inactive_tab_background #${config.colorScheme.palette.base08}
      inactive_tab_font_style bold
      tab_bar_background #${config.colorScheme.palette.base00}
      mouse_map left press ungrabbed mouse_selection normal
      mouse_map left doublepress ungrabbed mouse_selection word
      mouse_map left triplepress ungrabbed mouse_selection line 
      mouse_map right press ungrabbed mouse_paste
      mouse_map middle release ungrabbed paste_from_selection
      mouse_map shift+middle release ungrabbed,grabbed paste_selection
      mouse_map shift+middle press grabbed discard_event
    '';
  };
}
