{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.desktop.swaync;

  swayncConfig = {
    "$schema" = "${pkgs.swaynotificationcenter}/etc/xdg/swaync/configSchema.json";

    # Position settings
    positionX = "left";
    positionY = "bottom";

    # Control center margins
    control-center-margin-top = 10;
    control-center-margin-bottom = 10;
    control-center-margin-right = 10;
    control-center-margin-left = 10;

    # Scale factors to fix GDK monitor assertion
    control-center-scale = 1;
    notification-window-scale = 1;

    # Notification window settings
    notification-icon-size = 64;
    notification-body-image-height = 100;
    notification-body-image-width = 200;

    # Timeout settings
    timeout = 10;
    timeout-low = 5;
    timeout-critical = 0;

    # Window behavior
    fit-to-screen = true;
    notification-window-positionX = "left";
    notification-window-positionY = "bottom";

    # Layer shell configuration
    layer-shell = true;
    cssPriority = "application";
    transition-time = 200;
    hide-on-clear = true;
    hide-on-action = true;

    # Widget configuration
    widgets = [
      "dnd"
      "title"
      "notifications"
      "mpris"
      "volume"
      "buttons-grid"
    ];

    widget-config = {
      dnd = {
        text = "Do not disturb";
      };

      title = {
        text = "Notifications";
        clear-all-button = true;
        button-text = " 󰆴";
      };

      mpris = {
        contents = [
          "album-art"
          "icon"
          "title"
          "artist"
          "controls"
          "position"
        ];

        mouse-actions = {
          on-scroll-up = "NEXT";
          on-scroll-down = "PREV";
        };

        # Album art configuration
        album-art-size = 110;
        image-size = 110;
        text-overflow = "ellipsis";
        hide-when-inactive = true;
        force-artwork = true;

        # Supported media players
        preferred-players = [
          "spotify"
          # "mpd"
          # "firefox"
          # "chromium"
          # "vlc"
        ];
      };

      volume = {
        label = "󰕾";
        show-per-app = true;
      };

      buttons-grid = {
        actions = [
          {
            label = "󰐥";
            command = "systemctl poweroff";
          }
          {
            label = "";
            command = "systemctl reboot";
          }
          {
            label = "󰌾";
            command = "hyprlock";
          }
          {
            label = "󰍃";
            command = "hyprctl dispatch exit";
          }
          {
            label = "󰤄";
            command = "systemctl suspend";
          }
          {
            label = "󰕾";
            command = "swayosd-client --output-volume mute-toggle";
          }
          {
            label = "󰍬";
            command = "swayosd-client --input-volume mute-toggle";
          }
          {
            label = "󰖩";
            command = "nm-connection-editor";
          }
          {
            label = "󰂯";
            command = "blueman-manager";
          }
          {
            label = " ";
            command = "obs";
          }
        ];

        # Optional: Control grid layout
        grid-width = 3; # Number of columns
        grid-height = 4; # Number of rows
      };
    };
  };
in {
  options.desktop.swaync = {
    enable = mkEnableOption "Sway notification center";
  };

  config = mkIf cfg.enable {
    # Disable stylix target for swaync
    stylix.targets.swaync.enable = false;

    home.packages = with pkgs; [
      swaynotificationcenter
    ];

    xdg.configFile = {
      "swaync/config.json".text = builtins.toJSON swayncConfig;
      "swaync/style.css".source = ./style.css;
    };

    wayland.windowManager.hyprland.settings = {
      exec-once = ["swaync"];

      # Optional layer rules (commented out as per original)
      # layerrule = [
      #   "animation slide top, swaync-control-center"
      #   "animation slide bottom, swaync-notification-window"
      # ];
    };
  };
}
