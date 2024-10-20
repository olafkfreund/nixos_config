{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.desktop.sway;
in {
  options.desktop.sway = {
    enable = mkEnableOption {
      default = false;
      description = "sway";
    };
  };
  config = mkIf cfg.enable {
    wayland.windowManager.sway = {
      enable = true;
      xwayland = true;
      wrapperFeatures.gtk = true;
      systemd = {
        enable = true;
        xdgAutostart = true;
      };
      extraConfig = ''
        output HEADLESS-1 pos 0 0 res 2560x1440
      '';
      extraSessionCommands = ''
      '';
      config = {
        terminal = "foot";
        startup = [
          {command = "foot";}
          {command = "wayvnc 0.0.0.0";}
          # {command = "waybar";}
        ];
        # output = {
        #   "*".bg = "/home/olafkfreund/Pictures/wallpapers/gruvbox/hypr/gruv-portal-cake.png fill";
        #   "*".scale = "1";
        # };

        focus = {followMouse = "always";};
        gaps = {
          inner = 5;
          outer = 5;
          smartGaps = true;
          smartBorders = "on";
        };
        colors = rec {
          background = "#504945";
          unfocused = {
            text = "#ebdbb2";
            border = "#fe8019";
            background = "#504945";
            childBorder = "#fe8019";
            indicator = "#504945";
          };
          focusedInactive = unfocused;
          urgent =
            unfocused
            // {
              text = "#ebdbb2";
              border = "#fb4934";
              childBorder = "#fb4934";
            };
          focused =
            unfocused
            // {
              childBorder = "#282828";
              border = "#282828";
              background = "#282828";
              text = "#ebdbb2";
            };
        };
        window = {
          border = 2;
          titlebar = false;
        };
        bars = [
          {
            fonts = {
              names = ["JetBrainsMono Nerd Font"];
              size = 10.5;
            };
            colors = {
              background = "#504945";
              statusline = "#282828";
              separator = "#282828";
              focusedWorkspace = {
                border = "#282828";
                background = "#282828";
                text = "#ebdbb2";
              };

              inactiveWorkspace = {
                border = "#504945";
                background = "#504945";
                text = "#ebdbb2";
              };

              urgentWorkspace = {
                border = "#504945";
                background = "#504945";
                text = "#fb4934";
              };

              bindingMode = {
                border = "#8ec07c";
                background = "#8ec07c";
                text = "#ebdbb2";
              };
            };
            mode = "dock";
            position = "top";
            trayOutput = "none";
            statusCommand = "${pkgs.i3status-rust}/bin/i3status-rs ~/.config/i3status-rust/config-top.toml";
          }
        ];
      };
    };
    programs.i3status-rust = {
      enable = true;
      bars.top = {
        blocks = [
          {
            block = "custom";
            command = "cat /etc/hostname";
            interval = "once";
          }
          {
            block = "custom";
            command = "whoami";
            interval = "once";
          }
          {
            block = "cpu";
            interval = 1;
          }
          {
            block = "load";
            format = " $icon $1m ";
            interval = 1;
          }
          {
            block = "memory";
          }
          {
            block = "disk_space";
            path = "/";
            info_type = "available";
            interval = 60;
            warning = 20.0;
            alert = 10.0;
          }
          {
            block = "time";
            interval = 60;
            format = " $timestamp.datetime(f:'%a %d/%m %R') ";
          }
        ];

        settings = {
          theme = {
            theme = "gruvbox-dark";
            overrides = {
              idle_bg = "#504945";
              idle_fg = "#ebdbb2";
            };
          };
        };
      };
    };
  };
}
