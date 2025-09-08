{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.desktop.swaync;
in
{
  options.desktop.swaync = {
    enable = mkEnableOption "SwayNC notification center";

    package = mkOption {
      type = types.package;
      default = pkgs.swaynotificationcenter;
      description = "SwayNC package to use";
    };
  };

  config = mkIf (cfg.enable && !(config.desktop.gnome.enable or false)) {
    home.packages = [ cfg.package ];

    # Enable swaync service via systemd
    systemd.user.services.swaync = {
      Unit = {
        Description = "SwayNC notification daemon";
        After = [ "graphical-session-pre.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/swaync";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    # SwayNC configuration
    xdg.configFile."swaync/config.json".text = builtins.toJSON {
      # Position notifications on left
      positionX = "left";
      positionY = "top";

      # Control center positioning - full height left side from top to bottom
      control-center-positionX = "left";
      control-center-positionY = "top";
      control-center-margin-top = 0;
      control-center-margin-bottom = 0;
      control-center-margin-right = 0;
      control-center-margin-left = 0;

      # Notification window positioning
      notification-window-positionX = "left";
      notification-window-positionY = "top";

      # Timeout settings
      timeout = 10;
      timeout-low = 5;
      timeout-critical = 0;

      # Control center dimensions - full height on left side
      control-center-width = 500;
      control-center-height = 0; # 0 means full screen height (top to bottom)
      control-center-layer = "overlay";
      control-center-exclusive-zone = false;
      fit-to-screen = true; # Ensure it fits screen properly

      # Notification window dimensions
      notification-window-width = 400;

      # Behavior - force no transparency
      layer-shell = true;
      transition-time = 0; # No transition animations
      hide-on-clear = true;
      hide-on-action = true;

      # Force completely solid appearance with no compositor effects
      cssPriority = "user";
      keyboard-shortcuts = true;

      # Additional transparency controls
      notification-2fa-action = true;
      notification-inline-replies = true;
      notification-body-image-height = 100;
      notification-body-image-width = 200;

      # Widgets
      widgets = [
        "dnd"
        "title"
        "notifications"
        "mpris"
        "volume"
        "buttons-grid"
      ];

      # Widget configurations
      widget-config = {
        dnd = {
          text = "Do not disturb";
        };

        title = {
          text = "Control Center";
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
          album-art-size = 110;
          image-size = 110;
          text-overflow = "ellipsis";
          hide-when-inactive = true;
          force-artwork = true;
          preferred-players = [ "spotify" "mpd" "firefox" ];
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
              label = "󰜉";
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
              command = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
            }
          ];
          grid-width = 3;
          grid-height = 2;
        };
      };
    };

    # SwayNC CSS styling - completely flat design like rofi with forced opacity
    xdg.configFile."swaync/style.css".text = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 14px;
        font-weight: normal;
        transition: none !important;
        animation: none !important;
        border: none !important;
        border-radius: 0px !important;
        outline: none !important;
        box-shadow: none !important;
        opacity: 1.0 !important;
        -gtk-icon-effect: none !important;
      }

      /* Override all GTK transparency and compositor effects */
      window {
        opacity: 1.0 !important;
        background: rgba(40, 40, 40, 1.0) !important;
        background-color: rgba(40, 40, 40, 1.0) !important;
        -gtk-window-decorations: none !important;
      }

      /* Force complete opacity on all elements */
      *, *:before, *:after {
        background-color: rgba(40, 40, 40, 1.0) !important;
        opacity: 1.0 !important;
      }

      /* Remove any compositor alpha blending */
      window.background {
        background: rgba(40, 40, 40, 1.0) !important;
        background-color: rgba(40, 40, 40, 1.0) !important;
      }

      /* Main control center - completely flat covering full left side */
      .control-center {
        background: rgba(40, 40, 40, 1.0) !important;
        background-color: rgba(40, 40, 40, 1.0) !important;
        border: none !important;
        border-radius: 0px !important;
        box-shadow: none !important;
        outline: none !important;
        margin: 0px !important;
        padding: 0;
        width: 500px !important;
        height: 100vh !important;
        min-height: 100vh !important;
        max-height: 100vh !important;
        opacity: 1.0 !important;
      }

      /* Control center window - force full height positioning */
      .control-center-window {
        background: rgba(40, 40, 40, 1.0) !important;
        background-color: rgba(40, 40, 40, 1.0) !important;
        border: none !important;
        border-radius: 0px !important;
        box-shadow: none !important;
        outline: none !important;
        width: 500px !important;
        height: 100vh !important;
        min-height: 100vh !important;
        max-height: 100vh !important;
        margin: 0px !important;
        padding: 0px !important;
        opacity: 1.0 !important;

        /* Force positioning from top to bottom on left */
        position: fixed !important;
        top: 0px !important;
        left: 0px !important;
        bottom: 0px !important;
      }

      /* Title widget */
      .control-center .widget-title {
        background: #282828 !important;
        background-color: #282828 !important;
        color: #ebdbb2;
        font-size: 14px;
        font-weight: bold;
        padding: 12px;
        border-radius: 0px;
        border: none;
        opacity: 1.0 !important;
      }

      .control-center .widget-title button {
        background: #282828 !important;
        background-color: #282828 !important;
        color: #fabd2f;
        border: none;
        border-radius: 0px;
        padding: 4px 8px;
        font-size: 14px;
        font-weight: bold;
      }

      .control-center .widget-title button:hover {
        background: #282828 !important;
        background-color: #282828 !important;
        color: #fabd2f;
      }

      /* DND widget */
      .control-center .widget-dnd {
        background: #282828 !important;
        background-color: #282828 !important;
        color: #ebdbb2;
        padding: 12px;
        border-radius: 0px;
        border: none;
        margin: 0px;
      }

      .control-center .widget-dnd button {
        background: #282828 !important;
        background-color: #282828 !important;
        color: #ebdbb2;
        border: none;
        border-radius: 0px;
        padding: 8px 12px;
        font-weight: bold;
      }

      .control-center .widget-dnd button.enabled {
        background: #282828 !important;
        background-color: #282828 !important;
        color: #fabd2f;
      }

      /* Notifications */
      .notification {
        background: #282828 !important;
        background-color: #282828 !important;
        border: none;
        border-radius: 0px;
        margin: 0px;
        padding: 0;
        box-shadow: none;
        opacity: 1.0 !important;
      }

      .notification .notification-content {
        background: #282828 !important;
        background-color: #282828 !important;
        color: #ebdbb2;
        padding: 12px;
        opacity: 1.0 !important;
      }

      .notification .notification-default-action {
        background: #282828 !important;
        background-color: #282828 !important;
        color: #ebdbb2;
        border: none;
        border-radius: 0px;
      }

      .notification .notification-default-action:hover {
        background: #282828 !important;
        background-color: #282828 !important;
        color: #fabd2f;
      }

      .notification .summary {
        color: #ebdbb2;
        font-size: 14px;
        font-weight: bold;
        margin-bottom: 4px;
      }

      .notification .body {
        color: #ebdbb2;
        font-size: 12px;
      }

      .notification .app-name {
        color: #fabd2f;
        font-size: 11px;
        font-weight: bold;
      }

      /* MPRIS widget */
      .control-center .widget-mpris {
        background: #282828 !important;
        background-color: #282828 !important;
        border-radius: 0px;
        border: none;
        margin: 0px;
        padding: 12px;
      }

      .control-center .widget-mpris .album-art {
        border-radius: 0px;
        margin-right: 12px;
      }

      .control-center .widget-mpris .title {
        color: #ebdbb2;
        font-size: 14px;
        font-weight: bold;
      }

      .control-center .widget-mpris .artist {
        color: #ebdbb2;
        font-size: 12px;
      }

      .control-center .widget-mpris button {
        background: #282828 !important;
        background-color: #282828 !important;
        color: #ebdbb2;
        border: none;
        border-radius: 0px;
        width: 32px;
        height: 32px;
        margin: 2px;
      }

      .control-center .widget-mpris button:hover {
        background: #282828 !important;
        background-color: #282828 !important;
        color: #fabd2f;
      }

      /* Volume widget */
      .control-center .widget-volume {
        background: #282828 !important;
        background-color: #282828 !important;
        border-radius: 0px;
        border: none;
        margin: 0px;
        padding: 12px;
      }

      .control-center .widget-volume .volume-slider {
        background: #282828 !important;
        background-color: #282828 !important;
        border-radius: 0px;
      }

      .control-center .widget-volume .volume-slider slider {
        background: #fabd2f;
        border-radius: 0px;
      }

      /* Buttons grid */
      .control-center .widget-buttons-grid {
        background: #282828 !important;
        background-color: #282828 !important;
        border-radius: 0px;
        border: none;
        margin: 0px;
        padding: 12px;
      }

      .control-center .widget-buttons-grid button {
        background: #282828 !important;
        background-color: #282828 !important;
        color: #ebdbb2;
        border: none;
        border-radius: 0px;
        width: 48px;
        height: 48px;
        margin: 4px;
        font-size: 16px;
        font-weight: bold;
      }

      .control-center .widget-buttons-grid button:hover {
        background: #282828 !important;
        background-color: #282828 !important;
        color: #fabd2f;
      }

      /* Floating notifications */
      .floating-notifications .notification {
        background: #282828 !important;
        background-color: #282828 !important;
        border: none;
        border-radius: 0px;
        box-shadow: none;
        margin: 0px;
        padding: 0;
        opacity: 1.0 !important;
      }

      .floating-notifications .notification .notification-content {
        background: #282828 !important;
        background-color: #282828 !important;
        color: #ebdbb2;
        padding: 16px;
        opacity: 1.0 !important;
      }

      .floating-notifications .notification .close-button {
        background: #282828 !important;
        background-color: #282828 !important;
        color: #fabd2f;
        border: none;
        border-radius: 0px;
        width: 24px;
        height: 24px;
        margin: 8px;
      }

      .floating-notifications .notification .close-button:hover {
        background: #282828 !important;
        background-color: #282828 !important;
        color: #fabd2f;
      }

      /* Action buttons in notifications - SMALL TEXT */
      .notification .notification-action {
        background: #282828 !important;
        background-color: #282828 !important;
        color: #fabd2f;
        border: none;
        border-radius: 0px;
        padding: 2px 6px;
        margin: 1px;
        font-size: 10px;
        font-weight: normal;
        cursor: pointer;
      }

      .notification .notification-action:hover {
        background: #282828 !important;
        background-color: #282828 !important;
        color: #fabd2f;
        text-decoration: underline;
      }

      /* Action text in popup notifications - VERY SMALL */
      .notification .actions {
        background: #282828 !important;
        background-color: #282828 !important;
        padding: 4px;
      }

      .notification .actions button {
        background: #282828 !important;
        background-color: #282828 !important;
        color: #fabd2f;
        border: none;
        border-radius: 0px;
        padding: 2px 4px;
        margin: 1px;
        font-size: 9px;
        font-weight: normal;
        cursor: pointer;
      }

      .notification .actions button:hover {
        background: #282828 !important;
        background-color: #282828 !important;
        color: #fabd2f;
        text-decoration: underline;
      }

      /* Critical notifications */
      .notification.critical {
        background: #282828 !important;
        background-color: #282828 !important;
      }

      .notification.critical .summary {
        color: #fabd2f;
      }

      /* Low priority notifications */
      .notification.low {
        opacity: 1.0 !important;
        background: #282828 !important;
        background-color: #282828 !important;
      }

      /* Remove all window borders and decorations - FORCE FLAT */
      .notification-window,
      .control-center-window,
      window,
      .swaync-control-center,
      .swaync-notification-window {
        background: #282828 !important;
        background-color: #282828 !important;
        border: none !important;
        border-radius: 0px !important;
        outline: none !important;
        box-shadow: none !important;
        -gtk-outline-radius: 0px !important;
        -gtk-outline-width: 0px !important;
      }

      /* Force remove any GTK window decorations and transparency */
      window.swaync-control-center,
      window.swaync-notification-window {
        background: rgba(40, 40, 40, 1.0) !important;
        background-color: rgba(40, 40, 40, 1.0) !important;
        border: none !important;
        border-radius: 0px !important;
        outline: none !important;
        box-shadow: none !important;
        -gtk-outline-radius: 0px !important;
        -gtk-outline-width: 0px !important;
        opacity: 1.0 !important;
      }

      /* Force solid background on control center and notifications */
      .swaync-control-center,
      .swaync-notification-window,
      .control-center,
      .control-center-window {
        background: rgba(40, 40, 40, 1.0) !important;
        background-color: rgba(40, 40, 40, 1.0) !important;
        opacity: 1.0 !important;
      }

      /* Scrollbars - hidden like rofi */
      scrollbar {
        background: rgba(40, 40, 40, 1.0) !important;
        background-color: rgba(40, 40, 40, 1.0) !important;
        border-radius: 0px;
        width: 0px;
      }

      scrollbar slider {
        background: #282828 !important;
        background-color: #282828 !important;
        border-radius: 0px;
        min-height: 0px;
      }

      scrollbar slider:hover {
        background: #282828 !important;
        background-color: #282828 !important;
      }
    '';

    # Hyprland integration
    wayland.windowManager.hyprland = mkIf config.wayland.windowManager.hyprland.enable {
      settings = {
        bind = [
          "SUPER, N, exec, swaync-client -t -sw"
          "SUPER SHIFT, N, exec, swaync-client -d -sw"
        ];

        layerrule = [
          "animation slide left, swaync-control-center"
          "animation slide top, swaync-notification-window"
        ];
      };
    };

    # Create helper scripts
    home.file = {
      ".local/bin/swaync-toggle" = {
        text = ''
          #!/bin/sh
          swaync-client -t -sw
        '';
        executable = true;
      };

      ".local/bin/swaync-dismiss" = {
        text = ''
          #!/bin/sh
          swaync-client -d -sw
        '';
        executable = true;
      };
    };
  };
}
