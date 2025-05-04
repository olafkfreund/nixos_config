{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
with lib; let
  cfg = config.desktop.dunst;
in {
  options.desktop.dunst = {
    enable = mkEnableOption "Dunst notification daemon";
  };

  config = mkIf cfg.enable {
    services.dunst = {
      enable = true;

      settings = {
        global = {
          # Appearance
          background = "#${config.colorScheme.palette.base00}";
          foreground = "#${config.colorScheme.palette.base06}";
          frame_width = 0;
          frame_color = "#${config.colorScheme.palette.base05}";
          corner_radius = 10;
          icon_corner_radius = 5;
          transparency = 5;
          separator_height = 5;

          # Sizing and positioning
          monitor = 0;
          follow = "mouse";
          width = "(300,600)"; # Minimum width of 300
          height = 350;
          origin = "top-right";
          offset = "10x10";
          notification_limit = 5;

          # Progress bar settings
          progress_bar = true;
          progress_bar_height = 10; # Reduced height for better aesthetics
          progress_bar_frame_width = 1; # Thinner frame
          progress_bar_min_width = 460;
          progress_bar_max_width = 480;

          # Text formatting
          font = "JetBrains Mono Nerd Font 11"; # Slightly smaller font
          line_height = 2;
          markup = "full";
          format = "<b>%s</b>\\n%b"; # Add explicit format
          alignment = "left";
          word_wrap = true;
          ellipsize = "middle";
          ignore_newline = false; # Changed to respect newlines
          show_age_threshold = 60;

          # Icon settings
          icon_position = "left";
          max_icon_size = 64; # Reduced for better balance
          min_icon_size = 32;
          icon_theme = "Papirus";
          enable_recursive_icon_lookup = true;
          icon_path = "${pkgs.papirus-icon-theme}/share/icons/Papirus/16x16/status/:${pkgs.papirus-icon-theme}/share/icons/Papirus/16x16/devices/";

          # Behavior
          sort = true;
          idle_threshold = 120; # More reasonable idle threshold
          indicate_hidden = true;
          shrink = true;
          padding = 10;
          horizontal_padding = 10;
          sticky_history = true;
          history_length = 20;
          browser = "${pkgs.xdg-utils}/bin/xdg-open";
          dmenu = "${pkgs.rofi-wayland}/bin/rofi -dmenu -p dunst:"; # Using rofi instead
          always_run_script = true;
          title = "Dunst";
          class = "Dunst";

          # Mouse actions
          mouse_left_click = "close_current";
          mouse_middle_click = "do_action";
          mouse_right_click = "context_all";

          # Advanced settings
          stack_duplicates = true;
          hide_duplicate_count = false;
          show_indicators = true;
          ignore_dbusclose = true;
        };

        urgency_normal = {
          timeout = 6;
          background = "#${config.colorScheme.palette.base00}";
          frame_color = "#${config.colorScheme.palette.base07}";
          foreground = "#${config.colorScheme.palette.base06}";
        };

        urgency_low = {
          timeout = 4; # Increased from 2
          background = "#${config.colorScheme.palette.base00}";
          frame_color = "#${config.colorScheme.palette.base07}";
          foreground = "#${config.colorScheme.palette.base06}";
        };

        urgency_critical = {
          timeout = 0; # 0 = don't expire automatically
          background = "#${config.colorScheme.palette.base00}";
          frame_color = "#ff0000"; # Red frame for critical notifications
          foreground = "#${config.colorScheme.palette.base06}";
          frame_width = 2; # Add frame for critical notifications
        };

        fullscreen_show_critical = {
          msg_urgency = "critical";
          fullscreen = "pushback"; # Show critical notifications even in fullscreen
        };

        # Application-specific rules
        network = {
          appname = "network";
          new_icon = "network";
          summary = "*";
        };

        NetworkManager_Applet = {
          appname = "NetworkManager Applet";
          new_icon = "network-wireless";
        };

        # Added application rules
        spotify = {
          appname = "spotify";
          new_icon = "spotify";
        };

        volume = {
          appname = "*volume*";
          new_icon = "audio-volume-medium";
          timeout = 2;
        };

        power = {
          appname = "*power*";
          new_icon = "battery";
        };
      };
    };

    # Ensure necessary packages are available
    home.packages = with pkgs; [
      libnotify # Notification sending library
      papirus-icon-theme # Icon theme used by dunst
    ];
  };
}
