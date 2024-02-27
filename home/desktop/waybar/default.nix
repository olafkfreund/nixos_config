{ inputs
, pkgs
, config
, nix-colors
, ...
}:{
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        spacing = 4;

        modules-left = [ "custom/nixoslogo" "temperature" "hyprland/workspaces" "hyprland/submap" "custom/cmus" ];
        modules-center = [ "idle_inhibitor" "clock" ];
        modules-right = [ "pulseaudio" "network" "backlight" "disk" "battery#bat0" "battery#bat1" "tray" ];

        "custom/cmus" = {
          format = "󰎆  {}";
          max-length = 30;
          interval = 5;
          exec = ''cmus-remote -C "format_print '%t'"''; # %a artist - %t title
          exec-if = "pgrep cmus";
          on-click-right = "cmus-remote -n"; # next
          on-click-middle = "cmus-remote -u"; # toggle pause
          on-click = "cmus-remote -r"; # prev
          on-scroll-up = "cmus-remote -k +1";
          on-scroll-down = "cmus-remote -k -1";
          escape = true; # handle markup entities
          tooltip = false;
        };

        "custom/nixoslogo" = {
          format = " 󱄅 ";
          tooltip = false;
          on-click = "rofi -show drun";
          on-click-right = "rofi-powermenu";
          on-click-middle = "chpaper";
        };

        keyboard-state = {
          numlock = true;
          capslock = true;
          format = "{name} {icon}";
          format-icons = {
            locked = "";
            unlocked = "";
          };
        };
        "hyprland/workspaces" = {
          format = "{icon}";
          on-scroll-up = "hyprctl dispatch workspace e+1";
          on-scroll-down = "hyprctl dispatch workspace e-1";
          on-click = "activate";
        };
        idle_inhibitor = {
          format = "{icon}";
          format-icons = {
            activated = "";
            deactivated = "";
          };
        };
        temperature = {
          # "thermal-zone" = 2;
          "hwmon-path" = "/sys/class/hwmon/hwmon6/temp1_input";
          critical-threshold = 80;
          # format-critical = "{temperatureC}°C {icon}";
          format = "{temperatureC}°C";
          # format-icons = ["" "" ""];
        };
        tray = {
          spacing = 10;
        };
        clock = {
          interval = 60;
          format = "   {:%H:%M}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt> ";
          # format-alt = "{:%Y-%m-%d}";
          format-alt = "{:%a, %b %d, %Y (%R)}";
          "calendar" = {
            "mode" = "year";
            "mode-mon-col" = 3;
            "weeks-pos" = "";
            "on-click-right" = "mode";
            "format" = {
              "months" = "<span color='#7daea3'><b>{}</b></span>";
              "days" = "<span color='#2a2827'><b>{}</b></span>";
              "weeks" = "<span color='#d8a657'><b>W{}</b></span>";
              "weekdays" = "<span color='#bd6f3e'><b>{}</b></span>";
              "today" = "<span color='#ea6962'><b><u>{}</u></b></span>";
            };
          };
          "actions" = {
            "on-click-right" = "mode";
            # "on-scroll-up" = "shift_up";
            # "on-scroll-down" = "shift_down";
          };
        };
        disk = {
          format = "{free} 󰋊";
          path = "/";
          format-alt = "{used} 󱁋";
        };
        backlight = {
          format = "{percent}% {icon}";
          on-scroll-up = "light -A 1";
          on-scroll-down = "light -U 1";
          # format-icons = [ "" "" "" "" "" "" "" "" "" ];
          format-icons = [ "󰃞" "󰃞" "󰃟" "󰃟" "󰃟" "󰃠" "󰃠" "󰃠" "󰃠" ];
        };
        "battery#bat0" = {
          adapter = "AC";
          bat = "BAT0";
          states = {
            warning = 30;
            critical = 10;
          };
          format = "{capacity}% {icon}";
          format-charging = "{capacity}% ";
          format-plugged = "{capacity}% ";
          format-alt = "{time} {icon}";
          format-icons = [ "" "" "" "" "" ];
        };
        "battery#bat1" = {
          bat = "BAT1";
          states = {
            good = 95;
            warning = 30;
            critical = 15;
          };
          format = "{capacity}% {icon}";
          format-charging = "{capacity}% ";
          format-plugged = "{capacity}% ";
          format-alt = "{time} {icon}";
          format-icons = [ "" "" "" "" "" ];
        };
        network = {
          format-wifi = "{essid} ({signalStrength}%) 󰤨";
          format-ethernet = "{ipaddr}/{cidr} ";
          tooltip-format = "<span color='#7daea3'>{ifname} via {gwaddr} </span>";
          format-linked = "{ifname} (No IP) ";
          format-disconnected = "Disconnected ⚠";
          format-alt = "{ifname}: {ipaddr}/{cidr}";
        };
        pulseaudio = {
          states = {
            high = 80;
          };
          format = "{volume}% {icon} {format_source}";
          format-bluetooth = "{volume}% {icon} {format_source}";
          format-bluetooth-muted = "󰝟 {icon} {format_source}";
          format-muted = "󰝟 {format_source}";
          format-source = "{volume}% ";
          format-source-muted = "";
          format-icons = {
            headphone = "󰋋";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = [ "󰕿" "󰖀" "󰕾" ];
          };
        };
      };
    };

    style = ''
      * {
        border: none;
        font-family: JetBrainsMono, Font Awesome, Roboto, Arial, sans-serif;
        font-size: 12px;
        color: #fbf1c7;
        border-radius: 20px;
      }

      window {
        font-weight: bold;
      }

      window#waybar {
        background: rgba(0, 0, 0, 0);
      }

      /*-----module groups----*/
      .modules-right {
        background-color: @theme_base_color;
        color: @theme_text_color;
        margin: 4px 10px 0 0;
      }
      .modules-center {
        background-color: @theme_base_color;
        color: @theme_text_color;
        margin: 4px 120px 0 0;
      }
      .modules-left {
        margin: 4px 0 0 10px;
        background-color: @theme_base_color;
        color: @theme_text_color;
      }
      /*-----modules indv----*/
        #workspaces button {
          padding: 1px 5px;
          /*background-color: transparent;*/
        }
        #workspaces button:hover {
          box-shadow: inherit;
          background-color: #7daea3;
        }
        #custom-nixoslogo button:hover {
          box-shadow: inherit;
          background-color: #7daea3;
        }

        #workspaces button.focused {
          background-color: #e78a4e;
          color: @theme_base_color;
          box-shadow: inset 0 -3px #ffffff;
        }

        #custom-cmus {
          background-color: #d8a657;
          color: @theme_base_color;
        }

        #network {
          background-color: #7daea3;
          color: @theme_base_color;
        }

        #clock {
          background-color: #2a2827;
          color: @theme_base_color;
        }

        #disk {
          background-color: #d3869b;
          color: @theme_base_color;
        }

        #temperature {
          background-color: #e78a4e;
          color: @theme_base_color;
        }

        #custom-nixoslogo {
          padding: 0 0 0 5px;
        }

        #clock,
        #backlight,
        #disk,
        #battery,
        #cpu,
        #memory,
        #temperature,
        #network,
        #pulseaudio,
        /*#custom-nixoslogo,*/
        #custom-cmus,
        #tray,
        #idle_inhibitor {
          padding: 0 10px 0 10px;
        }


        /*-----Indicators----*/
        #idle_inhibitor.activated {
          color: #2a2827;
        }
        #pulseaudio.muted {
          color: #ea6962;
        }
        #pulseaudio:not(.high) {
          color: #e78a4e;
        }
        #battery.charging {
          color: #d8a657;
        }
        #battery.warning:not(.charging) {
          color: #d8a657;
        }
        #battery.critical:not(.charging) {
          color: #2a2827;
          background-color: #ea6962;
        }
        #clock.calendar {
          font-size: 8px;
        }
    '';
  };
}