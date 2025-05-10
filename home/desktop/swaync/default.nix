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
    positionY = "top";
    control-center-margin-top = 10;
    control-center-margin-bottom = 10;
    control-center-margin-right = 10;
    control-center-margin-left = 10;
    widgets = [
      "buttons-grid"
      "dnd"
      "title"
      "notifications"
    ];
    widget-config = {
      buttons-grid.actions = [
        {
          label = "󰐥";
          command = "systemctl poweroff";
        }
        {
          label = "󰑐";
          command = "systemctl reboot";
        }
        {
          label = "󰌿";
          command = "hyprlock";
        }
      ];
      dnd = {
        text = "Do not disturb";
      };
      title = {
        text = "Notifications";
        clear-all-button = true;
        button-text = "󰆴";
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
