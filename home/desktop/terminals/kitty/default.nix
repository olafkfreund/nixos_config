{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.kitty;
in {
  options.kitty = {
    enable = mkEnableOption {
      default = false;
      description = "kitty";
    };
  };
  config = mkIf cfg.enable {
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
      package = pkgs.kitty;
      #Kitty theme
      # theme = "Gruvbox Material Dark Hard";
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
        inactive_tab_font_style = "italic";
        input_delay = 1;
        repaint_delay = 7;
        window_margin_width = 8;
        term = "xterm-kitty";
        placement_strategy = "center";
        hide_window_decorations = true;
        # background_opacity = 1.0;
        dynamic_background_opacity = true;
        copy_on_select = true;
        url_style = "curly";
        sync_to_monitor = true;
        mouse_hide_wait = 20;
        cursor_shape = "beam";
        cursor_blink_interval = 1;
        cursor_stop_blinking_after = 15;
        scrollback_lines = 100000;
        scrollback_pager = "kitty-scroll";
        #include ./kitty-themes/gruvbox_dark.conf
      };
      extraConfig = ''
        # Mouse mappings
        mouse_map left press ungrabbed mouse_selection normal
        mouse_map left doublepress ungrabbed mouse_selection word
        mouse_map left triplepress ungrabbed mouse_selection line
        mouse_map right press ungrabbed mouse_paste
        mouse_map middle release ungrabbed paste_from_selection
        mouse_map shift+middle release ungrabbed,grabbed paste_selection
        mouse_map shift+middle press grabbed discard_event

        # Font symbol mappings
        symbol_map U+e000-U+e00a,U+ea60-U+ebeb,U+e0a0-U+e0c8,U+e0ca,U+e0cc-U+e0d4,U+e200-U+e2a9,U+e300-U+e3e3,U+e5fa-U+e6b1,U+e700-U+e7c5,U+f000-U+f2e0,U+f300-U+f372,U+f400-U+f532,U+f0001-U+f1af0 Symbols Nerd Font Mono
        symbol_map U+2600-U+26FF Noto Color Emoji

        # URL handling
        detect_urls yes
        open_url_with default
      '';
      keybindings = {
        "ctrl+c" = "copy_or_interrupt";
        "ctrl+v" = "paste_from_clipboard";
        "ctrl+shift+c" = "copy_to_clipboard";
        "ctrl+shift+v" = "paste_from_clipboard";
        "ctrl+shift+equal" = "increase_font_size";
        "ctrl+shift+minus" = "decrease_font_size";
        "ctrl+shift+backspace" = "restore_font_size";
        "ctrl+shift+enter" = "new_window";
        "ctrl+shift+t" = "new_tab";
        "ctrl+shift+q" = "close_tab";
        "ctrl+shift+right" = "next_tab";
        "ctrl+shift+left" = "previous_tab";
        "ctrl+shift+l" = "next_layout";
        "ctrl+shift+." = "move_tab_forward";
        "ctrl+shift+," = "move_tab_backward";
        "ctrl+shift+f" = "show_scrollback";
        "ctrl+shift+escape" = "kitty_shell window";
      };
    };
  };
}
