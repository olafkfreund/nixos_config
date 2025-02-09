{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.desktop.swaync;
in {
  options.desktop.swaync = {
    enable = mkEnableOption {
      default = false;
      description = "Sway notification center";
    };
  };
  config = mkIf cfg.enable {
    services.swaync = {
      enable = true;
      package = pkgs.swaynotificationcenter;
      settings = {
        "$schema" = "/etc/xdg/swaync/configSchema.json";
        "positionX" = "right";
        "positionY" = "top";
        "layer" = "overlay";
        "control-center-layer" = "top";
        "layer-shell" = true;
        "cssPriority" = "application";
        "control-center-margin-top" = 0;
        "control-center-margin-bottom" = 0;
        "control-center-margin-right" = 0;
        "control-center-margin-left" = 0;
        "notification-2fa-action" = true;
        "notification-inline-replies" = false;
        "notification-icon-size" = 64;
        "notification-body-image-height" = 100;
        "notification-body-image-width" = 200;
        "timeout" = 10;
        "timeout-low" = 5;
        "timeout-critical" = 0;
        "fit-to-screen" = true;
        "control-center-width" = 500;
        "control-center-height" = 600;
        "notification-window-width" = 500;
        "keyboard-shortcuts" = true;
        "image-visibility" = "when-available";
        "transition-time" = 200;
        "hide-on-clear" = false;
        "hide-on-action" = true;
        "script-fail-notify" = false;
        "scripts" = {};
        "notification-visibility" = {
          "example-name" = {
            "state" = "muted";
            "urgency" = "Low";
            "app-name" = "Spotify";
          };
        };
        "widgets" = [
          "inhibitors"
          "title"
          "dnd"
          "mpris"
          "notifications"
        ];
        "widget-config" = {
          "inhibitors" = {
            "text" = "Inhibitors";
            "button-text" = "Clear All";
            "clear-all-button" = true;
          };
          "title" = {
            "text" = "Notifications";
            "clear-all-button" = true;
            "button-text" = "Clear All";
          };
          "dnd" = {
            "text" = "Do Not Disturb";
          };
          "label" = {
            "max-lines" = 5;
            "text" = "Label Text";
          };
          "mpris" = {
            "image-size" = 96;
            "image-radius" = 12;
          };
        };
      };
      style = ''
        * {
          all: unset;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 20px;
        }

        .notification-row {
          outline: none;
        }

        .notification-row:focus,
        .notification-row:hover {
          background: #282828;
        }

        .notification {
          border-radius: 10px;
          margin: 6px 12px;
          box-shadow: none;
          padding: 0;
          min-height: 100px;
        }

        .notification label {
          padding-left: 10px;
        }

        .low,
        .normal {
          background-color: #689d6a;
          padding: 4px 4px 4px 4px;
          border: none;
          border-radius: 10px;
        }

        .critical {
          background-color: #cc241d;
          padding: 4px 4px 4px 4px;
          border: none;
          border-radius: 10px;
        }

        .notification-content {
          background: transparent;
          padding: 10px;
          border-radius: 10px;
        }

        .close-button {
          background: #282828;
          color: #ebdbb2;
          text-shadow: none;
          padding: 0;
          border-radius: 100%;
          margin-top: 12px;
          margin-right: 16px;
          box-shadow: none;
          border: none;
          min-width: 24px;
          min-height: 24px;
        }

        .close-button:hover {
          box-shadow: none;
          background: #cc241d;
          transition: all 0.15s ease-in-out;
          border: none;
        }

        .notification-default-action {
          padding: 4px;
          margin: 0;
          box-shadow: none;
          background-color: #282828;
          border: none;
          border-bottom: 1px solid @sep-color;
          color: #ebdbb2;
          transition: all 0.15s ease-in-out;
        }

        .notification-action {
          border: none;
          padding: 4px;
          margin: 0;
          box-shadow: none;
          background-color:#282828;
          color: #ebdbb2;
          transition: all 0.15s ease-in-out;
        }

        .notification-default-action:hover {
          -gtk-icon-effect: none;
          background: #282828;
        }

        .notification-action:hover {
          -gtk-icon-effect: none;
          background: #282828;
        }

        .notification-default-action {
          border-radius: 8px;
        }

        /* When alternative actions are visible */
        .notification-default-action:not(:only-child) {
          border-bottom-left-radius: 0px;
          border-bottom-right-radius: 0px;
        }

        .notification-action {
          border-radius: 0px;
          border-top: none;
          border-right: none;
        }

        /* add bottom border radius to eliminate clipping */
        .notification-action:first-child {
          border-bottom-left-radius: 10px;
        }

        .notification-action:last-child {
          border-bottom-right-radius: 10px;
          border-right: 1px solid #689d6a;
        }

        .inline-reply {
          margin-top: 8px;
        }
        .inline-reply-entry {
          background: #282828;
          color: #ebdbb2;
          caret-color: #ebdbb2;
          border: 1px solid #689d6a;
          border-radius: 12px;
        }
        .inline-reply-button {
          margin-left: 4px;
          background: #282828;
          border: 1px solid #689d6a;
          border-radius: 12px;
          color: #ebdbb2;
        }
        .inline-reply-button:disabled {
          background: initial;
          color: #282828;
          border: 1px solid transparent;
        }
        .inline-reply-button:hover {
          background: #282828;
        }

        .image {
        }

        .body-image {
          margin-top: 6px;
          background-color: white;
          border-radius: 12px;
        }

        .summary {
          font-size: 22px;
          font-weight: bold;
          background: transparent;
          color: #ebdbb2;
          text-shadow: none;
        }

        .time {
          font-size: 16px;
          font-weight: bold;
          background: transparent;
          color: #ebdbb2;
          text-shadow: none;
          margin-right: 18px;
        }

        .body {
          font-size: 18px;
          font-weight: normal;
          background: transparent;
          color: #ebdbb2;
          text-shadow: none;
        }

        .control-center {
          background: #282828;
          padding-bottom: 25px;
          padding-top: 5px;
          padding-left: 10px;
          padding-right: 9px;
        }

        .control-center-list {
          background: transparent;
        }

        .control-center-list-placeholder {
          opacity: 0.5;
        }

        .floating-notifications {
          background: transparent;
        }

        /* Window behind control center and on all other monitors */
        .blank-window {
          background-color: transparent;
        }

        /*** Widgets ***/

        /* Title widget */
        .widget-title {
          margin: 8px;
          font-size: 1.5rem;
          font-weight: bold;
          color: #ebdbb2;
        }
        .widget-title > button {
          font-size: 20px;
          font-weight: bold;
          color: #ebdbb2;
          text-shadow: none;
          background-color: #282828;
          border: none;
          border-bottom: 8px solid #504945;
          border-left: 4px solid #504945;
          box-shadow: none;
          border-radius: 5px;
          padding-left: 15px;
          padding-right: 15px;
          padding-top: 5px;
          padding-bottom: 5px;
        }
        .widget-title > button:hover {
          background-color: #282828;
          border-bottom: 8px solid  #76a765;
          border-left: 4px solid #76a765;
        }

        /* DND widget */
        .widget-dnd {
          margin: 8px;
          font-size: 1.1rem;
          color: #ebdbb2;
        }
        .widget-dnd > switch {
          font-size: initial;
          border-radius: 100px;
          background: #282828;
          border: none;
          box-shadow: none;
          color: transparent;
          margin: 0px;
        }
        .widget-dnd > switch:checked {
          background: #689d6a;
        }
        .widget-dnd > switch slider {
          background: #282828;
          border-radius: 100px;
          padding-top: 0px;
          padding-bottom: 0px;
          min-height: 28px;
          min-width: 30px;
          margin: 0px;
        }

        /* Label widget */
        .widget-label {
          margin: 8px;
        }
        .widget-label > label {
          font-size: 1.1rem;
        }

        /* Mpris widget */
        .widget-mpris {
          /* The parent to all players */
        }
        .widget-mpris-player {
          padding: 8px;
          margin: 8px;
        }
        .widget-mpris-title {
          font-weight: bold;
          font-size: 1.25rem;
        }
        .widget-mpris-subtitle {
          font-size: 1.1rem;
        }

        /* Buttons widget */
        .widget-buttons-grid {
          padding: 8px;
          margin: 8px;
          border-radius: 12px;
          background-color: #282828;
        }

        .widget-buttons-grid>flowbox>flowboxchild>button{
          background: #282828;
          border-radius: 12px;
        }

        .widget-buttons-grid>flowbox>flowboxchild>button:hover {
          background: #282828;
        }

        /* Menubar widget */
        .widget-menubar>box>.menu-button-bar>button {
          border: none;
          background: transparent;
        }

        .AnyName {
          background-color: #282828;
          padding: 8px;
          margin: 8px;
          border-radius: 10px;
        }

        .AnyName>button {
          background-color: transparent;
          border: none;
        }

        .AnyName>button:hover {
          background-color: #282828;
        }

        .topbar-buttons>button { /* Name defined in config after # */
          border: none;
          background: transparent;
        }

        /* Volume widget */

        .widget-volume {
          background-color: #282828;
          padding: 8px;
          margin: 8px;
          border-radius: 12px;
        }

        .widget-volume>box>button {
          background: transparent;
          border: none;
        }

        .per-app-volume {
          background-color: #282828;
          padding: 4px 8px 8px 8px;
          margin: 0px 8px 8px 8px;
          border-radius: 12px
        }

        /* Backlight widget */
        .widget-backlight {
          background-color: #282828;
          padding: 8px;
          margin: 8px;
          border-radius: 12px;
        }

        /* Title widget */
        .widget-inhibitors {
          margin: 8px;
          font-size: 1.5rem;
        }
        .widget-inhibitors > button {
          font-size: initial;
          color: #ebdbb2;
          text-shadow: none;
          background: #282828;
          border: 1px solid #bdae93;
          box-shadow: none;
          border-radius: 12px;
        }
        .widget-inhibitors > button:hover {
          background: #282828;
        }
      '';
    };
  };
}
