{ config, lib, pkgs, ... }:

with lib;

let
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

  config = mkIf cfg.enable {
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
      positionX = "left";
      positionY = "top";
      
      # Control center positioning - keep on left side only
      control-center-positionX = "left";
      control-center-positionY = "top";
      control-center-margin-top = 10;
      control-center-margin-bottom = 10;
      control-center-margin-right = 10;
      control-center-margin-left = 10;
      
      # Notification window positioning
      notification-window-positionX = "left";
      notification-window-positionY = "top";
      
      # Timeout settings
      timeout = 10;
      timeout-low = 5;
      timeout-critical = 0;
      
      # Control center dimensions - limit to left side
      control-center-width = 500;
      control-center-height = 600;
      control-center-layer = "overlay";
      control-center-exclusive-zone = false;
      
      # Notification window dimensions
      notification-window-width = 400;
      
      # Behavior
      fit-to-screen = false;
      layer-shell = true;
      transition-time = 200;
      hide-on-clear = true;
      hide-on-action = true;
      
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
              label = "";
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

    # SwayNC CSS styling - completely flat design like rofi
    xdg.configFile."swaync/style.css".text = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 14px;
        font-weight: normal;
        transition: none;
        border: none !important;
        border-radius: 0px !important;
        outline: none !important;
        box-shadow: none !important;
      }
      
      /* Main control center - completely flat like rofi */
      .control-center {
        background: #282828;
        border: none !important;
        border-radius: 0px !important;
        box-shadow: none !important;
        outline: none !important;
        margin: 0px;
        padding: 0;
        max-width: 500px;
        width: 500px;
      }
      
      /* Remove any window decorations */
      .control-center-window {
        background: #282828;
        border: none !important;
        border-radius: 0px !important;
        box-shadow: none !important;
        outline: none !important;
        max-width: 500px;
        width: 500px;
      }
      
      /* Title widget */
      .control-center .widget-title {
        background: #282828;
        color: #ebdbb2;
        font-size: 14px;
        font-weight: bold;
        padding: 12px;
        border-radius: 0px;
        border: none;
      }
      
      .control-center .widget-title button {
        background: #282828;
        color: #fabd2f;
        border: none;
        border-radius: 0px;
        padding: 4px 8px;
        font-size: 14px;
        font-weight: bold;
      }
      
      .control-center .widget-title button:hover {
        background: #282828;
        color: #fabd2f;
      }
      
      /* DND widget */
      .control-center .widget-dnd {
        background: #282828;
        color: #ebdbb2;
        padding: 12px;
        border-radius: 0px;
        border: none;
        margin: 0px;
      }
      
      .control-center .widget-dnd button {
        background: #282828;
        color: #ebdbb2;
        border: none;
        border-radius: 0px;
        padding: 8px 12px;
        font-weight: bold;
      }
      
      .control-center .widget-dnd button.enabled {
        background: #282828;
        color: #fabd2f;
      }
      
      /* Notifications */
      .notification {
        background: #282828;
        border: none;
        border-radius: 0px;
        margin: 0px;
        padding: 0;
        box-shadow: none;
      }
      
      .notification .notification-content {
        background: #282828;
        color: #ebdbb2;
        padding: 12px;
      }
      
      .notification .notification-default-action {
        background: #282828;
        color: #ebdbb2;
        border: none;
        border-radius: 0px;
      }
      
      .notification .notification-default-action:hover {
        background: #282828;
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
        background: #282828;
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
        background: #282828;
        color: #ebdbb2;
        border: none;
        border-radius: 0px;
        width: 32px;
        height: 32px;
        margin: 2px;
      }
      
      .control-center .widget-mpris button:hover {
        background: #282828;
        color: #fabd2f;
      }
      
      /* Volume widget */
      .control-center .widget-volume {
        background: #282828;
        border-radius: 0px;
        border: none;
        margin: 0px;
        padding: 12px;
      }
      
      .control-center .widget-volume .volume-slider {
        background: #282828;
        border-radius: 0px;
      }
      
      .control-center .widget-volume .volume-slider slider {
        background: #fabd2f;
        border-radius: 0px;
      }
      
      /* Buttons grid */
      .control-center .widget-buttons-grid {
        background: #282828;
        border-radius: 0px;
        border: none;
        margin: 0px;
        padding: 12px;
      }
      
      .control-center .widget-buttons-grid button {
        background: #282828;
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
        background: #282828;
        color: #fabd2f;
      }
      
      /* Floating notifications */
      .floating-notifications .notification {
        background: #282828;
        border: none;
        border-radius: 0px;
        box-shadow: none;
        margin: 0px;
        padding: 0;
      }
      
      .floating-notifications .notification .notification-content {
        background: #282828;
        color: #ebdbb2;
        padding: 16px;
      }
      
      .floating-notifications .notification .close-button {
        background: #282828;
        color: #fabd2f;
        border: none;
        border-radius: 0px;
        width: 24px;
        height: 24px;
        margin: 8px;
      }
      
      .floating-notifications .notification .close-button:hover {
        background: #282828;
        color: #fabd2f;
      }
      
      /* Action buttons in notifications - SMALL TEXT */
      .notification .notification-action {
        background: #282828;
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
        background: #282828;
        color: #fabd2f;
        text-decoration: underline;
      }
      
      /* Action text in popup notifications - VERY SMALL */
      .notification .actions {
        background: #282828;
        padding: 4px;
      }
      
      .notification .actions button {
        background: #282828;
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
        background: #282828;
        color: #fabd2f;
        text-decoration: underline;
      }
      
      /* Critical notifications */
      .notification.critical {
        background: #282828;
      }
      
      .notification.critical .summary {
        color: #fabd2f;
      }
      
      /* Low priority notifications */
      .notification.low {
        opacity: 1.0;
      }
      
      /* Remove all window borders and decorations - FORCE FLAT */
      .notification-window,
      .control-center-window,
      window,
      .swaync-control-center,
      .swaync-notification-window {
        background: #282828;
        border: none !important;
        border-radius: 0px !important;
        outline: none !important;
        box-shadow: none !important;
        -gtk-outline-radius: 0px !important;
        -gtk-outline-width: 0px !important;
      }
      
      /* Force remove any GTK window decorations */
      window.swaync-control-center,
      window.swaync-notification-window {
        background: #282828;
        border: none !important;
        border-radius: 0px !important;
        outline: none !important;
        box-shadow: none !important;
        -gtk-outline-radius: 0px !important;
        -gtk-outline-width: 0px !important;
      }
      
      /* Scrollbars - hidden like rofi */
      scrollbar {
        background: #282828;
        border-radius: 0px;
        width: 0px;
      }
      
      scrollbar slider {
        background: #282828;
        border-radius: 0px;
        min-height: 0px;
      }
      
      scrollbar slider:hover {
        background: #282828;
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