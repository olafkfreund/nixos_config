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
    positionX = "left";
    positionY = "bottom";
    control-center-margin-top = 10;
    control-center-margin-bottom = 10;
    control-center-margin-right = 10;
    control-center-margin-left = 10;
    # Add explicit scale factor to fix GDK monitor assertion
    control-center-scale = 1;
    notification-window-scale = 1;

    # Notification window position settings
    notification-icon-size = 64;
    notification-body-image-height = 100;
    notification-body-image-width = 200;
    timeout = 10;
    timeout-low = 5;
    timeout-critical = 0;
    fit-to-screen = true;

    # These settings control where notifications appear
    notification-window-width = 300;
    notification-window-height = 100;
    notification-window-margin-left = 10;
    notification-window-margin-right = 0;
    notification-window-margin-bottom = 0;
    notification-window-margin-top = 10;
    notification-window-positionX = "left";
    notification-window-positionY = "bottom";

    # Disable any transparency/blur effects
    layer-shell = true;
    cssPriority = "application";
    transition-time = 200; # Fast transitions for a snappy feel
    hide-on-clear = true;
    hide-on-action = true;

    widgets = [
      "dnd"
      "title"
      "notifications"
      "mpris"
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
        # You can also adjust the album art size
        album-art-size = 110; # Increased size to ensure visibility
        # Control how truncated text is displayed
        text-overflow = "ellipsis";
        hide-when-inactive = true;
        # Force album art retrieval mode - can help with some players
        force-artwork = true;
        # Add these fields to improve compatibility
        image-size = 110;
        # Specifically tell swaync which players to support
        preferred-players = ["spotify" "mpd" "firefox" "chromium" "vlc"];
      };
    };
  };
in {
  options.desktop.swaync = {
    enable = mkEnableOption {
      default = false;
      description = "Sway notification center";
    };
  };

  config = mkIf cfg.enable {
    # Enable the stylix target for swaync
    stylix.targets.swaync.enable = false;

    home = {
      packages = [pkgs.swaynotificationcenter];
    };

    xdg.configFile = {
      "swaync/config.json".text = builtins.toJSON swayncConfig;
      "swaync/style.css".source = ./style.css;
    };

    wayland.windowManager.hyprland.settings = {
      exec-once = ["swaync"];
      layerrule = [
        "animation slide top, swaync-control-center"
        "animation slide top, swaync-notification-window"
      ];
    };
  };
}
