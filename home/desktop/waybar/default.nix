{ inputs, pkgs, config, self, lib, ...}: {
  programs.waybar = {
    enable = true;
    package = pkgs.waybar;
    settings = {
      mainBar = {
        "layer" = "top";
        "position" = "top";
        #"height" = 32;
        #"width" = 1800;
        "margin-top" = 10;
        "margin-bottom" = 3;
        "margin-left" = 400;
        "margin-right" = 400;
        "spacing" = 3;
        "fixed-center" = false;
        "exclusive" = true;
        "passthrough" = false;
        #"mode" = "dock";
        "reload_style_on_change" = true;
        "gtk-layer-shell" = true;

        "modules-left" = ["custom/startmenu" "hyprland/workspaces"];
        "modules-right" = [
          "group/monitor"
          "pulseaudio"
          "pulseaudio#microphone"
          "group/computer"
          "idle_inhibitor"
          ];
        "modules-center" = [ "clock" "group/group-power" ];

        "custom/cycle_wall" = {
          "format" = " ";
          "on-click" = "wallpaper_picker";
          "tooltip" = true;
          "tooltip-format" = "Change wallpaper";
        };
        "idle_inhibitor" = {
          "format" = "{icon}";
          "format-icons" = {
            "activated" = "󰥔";
            "deactivated" = "";
          };
        };
        "cava"= {
            "framerate" = 30;
            "autosens" = 0;
            "sensitivity" = 120;
            "bars" = 14;
            "lower_cutoff_freq" = 50;
            "higher_cutoff_freq" = 10000;
            "method" = "pulse";
            "source" = "auto";
            "stereo" = true;
            "reverse" = false;
            "bar_delimiter" = 0;
            "monstercat" = false;
            "waves" = false;
            "noise_reduction" = 0.77;
            "input_delay" = 2;
            "format-icons" = ["▁" "▂" "▃" "▄" "▅" "▆" "▇" "█" ];
            "actions" = {
              "on-click-right" = "kitty -e cava";
            };
        };
        "group/group-power" = {
          orientation = "inherit";
          drawer = {
            transition-duration = 500;
            transition-left-to-right = true;
        };
        modules = [
          "custom/power"
          "custom/quit"
          "custom/lock"
          "custom/reboot"
        ];
      };

        "custom/quit" = {
          format = "󰗼 ";
          on-click = "${pkgs.hyprland}/bin/hyprctl dispatch exit";
          tooltip = false;
        };

       "custom/lock" = {
          format = "󰍁 ";
          on-click = "${lib.getExe pkgs.hyprlock}";
          tooltip = false;
        };

        "custom/reboot" = {
          format = "󰜉 ";
          on-click = "${pkgs.systemd}/bin/systemctl reboot";
          tooltip = false;
        };

        "custom/power" = {
          format = " ";
          on-click = "${pkgs.systemd}/bin/systemctl poweroff";
          tooltip = false;
        };

        "custom/monitor" = {
          format = "";
          on-click = "${pkgs.wdisplays}/bin/wdisplays";
          tooltip = false;
        };
        "custom/startmenu" = {
          tooltip = false;
          format = " ";
          on-click = "sleep 0.1 && ~/.config/rofi/launchers/type-2/launcher.sh";
        };

        "hyprland/workspaces" = {
	        "format" = "{icon}";
          "on-click" = "active";
          "on-scroll-up" = "${pkgs.hyprland}/bin/hyprctl dispatch workspace e-1";
          "on-scroll-down" = "${pkgs.hyprland}/bin/hyprctl dispatch workspace e+1";
          "max-length" = 45;
          "persistent-workspaces" = {
            "1" = [];
            "2" = [];
            "3" = [];
            "4" = [];
            "5" = [];
            "6" = [];
            "7" = [];
            "8" = [];
            "9" = [];
            "10" = [];
          };
	        "format-icons" = {
            "1" = " ";
            "2" = " ";
            "3" = " ";
            "4" = " ";
            "5" = " ";
            "6" = " ";
            "7" = " ";
            "8" = " ";
            "9" = " ";
            "10" = " ";
            "active" = " ";
            "default" = " ";
            "urgent" = " ";
            "magic" = "󰐃 ";
            "hidden" = "󰐃 ";
            "secret" = "󰐃 ";
          };
	      };
        "group/monitor" = {
          orientation = "inherit";
          drawer = {
            transition-duration = 500;
            transition-left-to-right = false;
          };
          modules = [
            "network"
            "cpu"
            "memory"
            "backlight"
            "battery"
            "disk"
            "bluetooth"
          ];
        };
        "group/computer" = {
          orientation = "inherit";
          drawer = {
            transition-duration = 500;
            transition-left-to-right = false;
          };
          modules = [
            "custom/cycle_wall"
            "custom/monitor"
          ];
        };
        "hyprland/window" = {
          "format" = " {}";
          "separate-outputs" = true;
        };
        "tray" = {
          "spacing" = 12;
          "show-passive-items" = true;
        };
        "custom/dunst" = {
          return-type = "json";
          exec = "dunst-waybar";
          on-click = "dunstctl set-paused toggle";
          restart-interval = 1;
        };
        "hyprland/language" = {
          "format" = " {}";
          "format-en" = "Gb";
          "format-nb" = "No";
          "max-length" = 5;
          "min-length" = 5;
          "keyboard-name" = "at-translated-set-2-keyboard";
          "on-click-right" = "~/.config/rofi/applets/bin/clipboard.sh";
        };
            "clock" = {
            "format" = "{:%H:%M}";
            "max-lenght" = 25;
            "min-length" = 6;
            "format-alt" = "{:%A, %B %d, %Y (%R)}";
            "tooltip-format" = "<tt><small>{calendar}</small></tt>";
            "calendar" = {
                "mode" = "year";
                "mode-mon-col" = 3;
                "weeks-pos" = "right";
                "on-scroll" = 1;
                "on-click-right" = "mode";
                "format" = {
                    "months" = "<span color='#${config.colorScheme.palette.base06}'><b>{}</b></span>";
                    "days" =   "<span color='#${config.colorScheme.palette.base06}'><b>{}</b></span>";
                    "weeks" =  "<span color='#${config.colorScheme.palette.base09}'><b>W{}</b></span>";
                    "weekdays" = "<span color='#${config.colorScheme.palette.base05}'><b>{}</b></span>";
                    "today" =   "<span color='#${config.colorScheme.palette.base08}'><b><u>{}</u></b></span>";
                    };
              };
            "actions" =  {
                        "on-click-right" = "mode";
                        "on-click-forward" = "tz_up";
                        "on-click-backward" = "tz_down";
                        "on-scroll-up" = "shift_up";
                        "on-scroll-down" = "shift_down";
                      };
            };
        "cpu" = {
          "interval" = 1;
          "format" = "󰍛 {usage}%";
          "format-icons" = ["▁" "▂" "▃" "▄" "▅" "▆" "▇" "█"];
          "on-click" = "kitty --class system_monitor -e btm";
          "max-lenght" = 25;
          "min-length" = 6;
        };
        "memory" = {
          "format" = "󰾆 {percentage}%";
          "interval" = 1;
          "on-click" = "kitty --class system_monitor -e btm";
          "max-lenght" = 25;
          "min-length" = 6;
        };
        "backlight" = {
          "format" = "{icon}{percent}%";
          "format-icons" = [" " " " " " " " " " " " " " " " " "];
          "on-scroll-up" = "brightnessctl set 30+";
          "on-scroll-down" = "brightnessctl set 30-";
          "max-lenght" = 25;
          "min-length" = 6;
        };
        "battery" = {
          "states" = {
            "good" = 80;
            "warning" = 30;
            "critical" = 20;
          };
          "format" = "{icon} {capacity}%";
          "format-charging" = " {capacity}%";
          "format-plugged" = " {capacity}%";
          "format-alt" = "{time} {icon}";
          "format-icons" = ["󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"];
        };
        "network" = {
          "format-wifi" = "󰤨 {essid}";
          "format-ethernet" = "󱘖 Wired";
          "tooltip-format" = "󱘖 {ipaddr}  {bandwidthUpBytes}  {bandwidthDownBytes}";
          "format-linked" = "󱘖 {ifname} (No IP)";
          "format-disconnected" = " Disconnected";
          "format-alt" = "󰤨 {signalStrength}%";
          "on-click" = "networkmanager_dmenu";
        };
        "bluetooth" = {
          "format" = "";
          "format-disabled" = ""; # an empty format will hide the module
          "format-connected" = " {num_connections}";
          "tooltip-format" = " {device_alias}";
          "tooltip-format-connected" = "{device_enumerate}";
          "tooltip-format-enumerate-connected" = " {device_alias}";
        };
        "disk" = {
          "interval" = 30;
          "format" = "󰋊 {percentage_used}%";
          "path" = "/";
          "tooltip" = true;
          "tooltip-format" = "HDD - {used} used out of {total} on {path} ({percentage_used}%)";
          "on-click" = "kitty --class system_monitor -e ncdu --color dark";
        };
        "pulseaudio" = {
          "format" = "{icon} {volume}";
          "format-muted" = "婢";
          "on-click" = "pavucontrol -t 3";
          "tooltip-format" = "{icon} {desc} // {volume}%";
          "scroll-step" = 5;
          "format-icons" = {
            "headphone" = "";
            "hands-free" = "";
            "headset" = "";
            "phone" = "";
            "portable" = "";
            "car" = "";
            "default" = ["" "" ""];
            }; 
          };
          "custom/playerctl" = {
            "format" = "{icon}  <span>{}</span>";
            "return-type" = "json";
            "exec"=  "${pkgs.playerctl}/bin/playerctl -p spotify metadata -f '{\"text\": \"{{markup_escape(title)}} - {{markup_escape(artist)}} {{ duration(position) }}/{{ duration(mpris:length) }}\", \"tooltip\": \"{{markup_escape(title)}} - {{markup_escape(artist)}}  {{ duration(position) }}/{{ duration(mpris:length) }}\", \"alt\": \"{{status}}\", \"class\": \"{{status}}\"}' -F";
            "tooltip" = false;
            "on-click-middle" = "${pkgs.playerctl}/bin/playerctl -p spotify previous";
            "on-click" = "${pkgs.playerctl}/bin/playerctl -p spotify play-pause";
            "on-click-right" = "${pkgs.playerctl}/bin/playerctl -p spotify next";
            "on-scroll-up" = "${pkgs.playerctl}/bin/playerctl -p spotify volume 0.02+";
            "on-scroll-down" = "${pkgs.playerctl}/bin/playerctl -p spotify volume 0.02-";
            "format-icons" = {
                "Paused" = "";
                "Playing" = "";
            };
        };
         "pulseaudio#microphone" = {
           "format" = "{format_source}";
           "format-source" = "";
           "format-source-muted" = " ";
           "on-click" = "pavucontrol -t 4";
           "tooltip-format" = "{format_source} {source_desc} // {source_volume}%";
           "scroll-step" = 5;
          };
      };
    };

    style = ''
      * {
        font-family: 'JetBrainsMono Nerd Font';
        font-size: 15px;
        /* font-weight: bold; */
        border-radius: 0px;
        margin: 1px;
        min-height: 0px;
        }

        window#waybar {
          background-color: #${config.colorScheme.palette.base00};
          border-radius: 6px;
          /* padding-top: 0px; */
          border: 2px solid rgba(29, 32, 33, 0.5);
          margin-top: 0;
        }

        .modules-right {
          font-size: 15px;
          background-color: #${config.colorScheme.palette.base00};
          border-radius: 0px;
          padding: 5px 10px;
          margin-top: 0px;
          margin-bottom: 0px;
          margin-right: 0.1px;
        }

        .modules-left {
          font-size: 15px;
          margin-left: 10px;
          background-color: #${config.colorScheme.palette.base00};
          margin-top: 0px;
          margin-bottom: 0px;
          padding: 1px 0px;
          border-radius: 0px;
        }

        .modules-center {
          font-size: 15px;
          margin-left: 10px;
          background-color: #${config.colorScheme.palette.base00};
          margin-top: 0px;
          margin-bottom: 0px;
          padding: 5px 10px;
          border-radius: 10px;
        }

        tooltip {
          background: #${config.colorScheme.palette.base00};
          border-radius: 0px;
        }

        tooltip label {
          color: #${config.colorScheme.palette.base06};
          background-color: #${config.colorScheme.palette.base00};
          border-radius: 0px;
        }

        tooltip * {
          border-radius: 0px;
        }

        #workspaces {
          margin: 0px;
          margin-right: 0.3px;
          margin-left: 0.3px;
        }

        #workspaces button {
          margin: 0px;
          color: #${config.colorScheme.palette.base06};
          font-weight: normal;
          font-style: normal;
          margin: 0.2px 0.2px;
          border-radius: 0px;
        }

        #workspaces button:hover {
          box-shadow: inherit;
          text-shadow: inherit;
          background-color: #${config.colorScheme.palette.base06};
          color: #${config.colorScheme.palette.base09};
          border-radius: 0px;
        }

        #workspaces button.active {
          color: #${config.colorScheme.palette.base09};
          background-color: #${config.colorScheme.palette.base0D};
          text-shadow: 0 0 5px rgba(0, 0, 0, 0.818);
          transition: all 0.1s ease-in-out;
          border-radius: 0px;
        }

        #workspaces button.urgent {
          color: #${config.colorScheme.palette.base08};
          text-shadow: 0 0 5px rgba(0, 0, 0, 0.818);
          transition: all 0.1s ease-in-out;
          border-radius: 0px;
        }

        #clock {
          font-size: 20px;
          font-weight: bolder;
          font-style: normal;
          margin: 0px;
          margin-right: 0.3px;
          margin-left: 0.3px;
          color: #${config.colorScheme.palette.base06};
        }

        #custom-startmenu {
          font-size: 20px;
          font-weight: bolder;
          font-style: normal;
          margin: 0px;
          margin-right: 0.3px;
          margin-left: 0.3px;
          color: #${config.colorScheme.palette.base0D};
        }

        #custom-power {
          font-size: 15px;
          font-weight: bolder;
          font-style: normal;
          padding: 0 5px;
          color: #${config.colorScheme.palette.base0D};
        }

        #custom-monitor {
          font-size: 15px;
          font-weight: bolder;
          font-style: normal;
          padding: 0 5px;
          color: #${config.colorScheme.palette.base0D};
        }
        
        #custom-quit, #custom-lock, #custom-reboot {
          font-size: 20px;
          font-weight: bolder;
          font-style: normal;
          padding: 0 5px;
          color: #${config.colorScheme.palette.base0A};
        }

        #custom-spotify {
          padding: 0 5px;
        }
        #memory {
          color: #${config.colorScheme.palette.base09};
          padding: 0 5px;
        }

        #pulseaudio {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base0D};
        }

        #pulseaudio#microphone {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base0D};
        }

        #pulseaudio.muted {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base08};
        }

        #backlight {
          padding: 0 0.5px 0 0.4em;
          color: #${config.colorScheme.palette.base09};
        }

        #cpu {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base09};
        }

        #network {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base0D};
        }

        #custom-cycle_wall {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base0D};
        }
        
        #idle_inhibitor {
          padding: 0 5px; 
          font-size: 20px;
          font-weight: bolder;
          font-style: normal;
          color: #${config.colorScheme.palette.base0D};
        }

        #idle_inhibitor.activated {
          padding: 0 5px;
          font-size: 20px;
          font-weight: bolder;
          font-style: normal;
          color: #${config.colorScheme.palette.base0D};
        }

        #language {
          margin: 0;
          padding: 0 0.4px 0 0.5px;
          color: #${config.colorScheme.palette.base06};
        }

        #tray {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base06};
        }

        #battery {
          padding: 0 0.5px 0 0.8px;
          color: #${config.colorScheme.palette.base09};
        }

        #disk {
          padding: 0 0.1px 0 0.1px;
          color:  #${config.colorScheme.palette.base09};
        }

        #cava {
          padding: 0 0.1px 0 0.1px;
          color:  #${config.colorScheme.palette.base06};
        }

        #window {
          color: #${config.colorScheme.palette.base06};
          margin-left: 1px;
          margin-right: 1px;
          text-shadow: 0 0 5px rgba(0, 0, 0, 0.818);
          transition: all 0.1s ease-in-out;
          border-radius: 0px;
          font-size: 15px;
        }
    '';
  };
}
