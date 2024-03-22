{ inputs
, pkgs
, pkgs-stable
, config
, self
, lib
, ...
}:{
  programs.waybar = {
    enable = true;
    package = pkgs-stable.waybar;
    settings = {
      mainBar = {
        "layer" = "top";
        "position" = "top";
        "height" = 0;
        #"width" = 1800;
        "margin-bottom" = 5;
        "spacing" = 0;
        "fixed-center" = true;
        "exclusive" = true;
        "passthrough" = false;
        "mode" = "dock";
        "reload_style_on_change" = true;
        "gtk-layer-shell" = true;

        "modules-left" = [ "hyprland/workspaces" "hyprland/window"];
        "modules-right" = [
          "idle_inhibitor"
          "memory"
          "cpu"
          "battery"
          "pulseaudio"
          "pulseaudio#microphone"
          "network"
          "backlight"
          "custom/monitor"
          "custom/cycle_wall"
          "hyprland/language"
          "tray"
        ];
        "modules-center" = [ "clock" "group/group-power" ];

        "custom/cycle_wall" = {
          "format" = " ";
          "on-click" = "~/.config/hypr/scripts/wall";
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
            transition-left-to-right = false;
        };
        modules = [
          "custom/power"
          "custom/quit"
          "custom/lock"
          "custom/reboot"
        ];
      };

        "custom/quit" = {
          format = "󰗼";
          on-click = "${pkgs.hyprland}/bin/hyprctl dispatch exit";
          tooltip = false;
        };

       "custom/lock" = {
          format = "󰍁";
          on-click = "${lib.getExe pkgs.hyprlock}";
          tooltip = false;
        };

        "custom/reboot" = {
          format = "󰜉";
          on-click = "${pkgs.systemd}/bin/systemctl reboot";
          tooltip = false;
        };

        "custom/power" = {
          format = "";
          on-click = "${pkgs.systemd}/bin/systemctl poweroff";
          tooltip = false;
        };

        "custom/monitor" = {
          format = "";
          on-click = "${pkgs.wdisplays}/bin/wdisplays";
          tooltip = false;
        };

        "hyprland/workspaces" = {
	        "format" = "{icon}";
          "on-click" = "active";
          "on-scroll-up" = "hyprctl dispatch workspace e-1";
          "on-scroll-down" = "hyprctl dispatch workspace e+1";
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
          "1" = "";
          "2" = "";
          "3" = "󰙀";
          "4" = "";
          "5" = "";
          "6" = "";
          "7" = "";
          "8" = "󰓇";
          "9" = "";
          "10" = "";
		      "active" = "";
		      "default" = "";
          "urgent" = "";
          "magic" = "󰐃";
          "hidden" = "󰐃";
          };
	      };
        "hyprland/window" = {
          "format" = " {}";
          "separate-outputs" = true;
        };
        "tray" = {
          "icon-size" = 21;
          "spacing" = 4;
          "show-passive-items" = true;
          "max-length" = 20;
          "min-length" = 10;
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
            "format" = "{:%H:%M}  ";
            "max-lenght" = 25;
            "min-length" = 6;
            "format-alt" = "{:%A, %B %d, %Y (%R)}  ";
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
            "exec"=  "playerctl -p spotify metadata -f '{\"text\": \"{{markup_escape(title)}} - {{markup_escape(artist)}} {{ duration(position) }}/{{ duration(mpris:length) }}\", \"tooltip\": \"{{markup_escape(title)}} - {{markup_escape(artist)}}  {{ duration(position) }}/{{ duration(mpris:length) }}\", \"alt\": \"{{status}}\", \"class\": \"{{status}}\"}' -F";
            "tooltip" = false;
            "on-click-middle" = "playerctl -p spotify previous";
            "on-click" = "playerctl -p spotify play-pause";
            "on-click-right" = "playerctl -p spotify next";
            "on-scroll-up" = "playerctl -p spotify volume 0.02+";
            "on-scroll-down" = "playerctl -p spotify volume 0.02-";
            "format-icons" = {
                "Paused" = "";
                "Playing" = "";
            };
        };
         "pulseaudio#microphone" = {
           "format" = "{format_source}";
           "format-source" = "";
           "format-source-muted" = "";
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
        margin: 0;
        }

        window#waybar {
          background-color: #${config.colorScheme.palette.base00};
          border-radius: 10px;
          padding-top: 0px;
          margin-top: 0;
        }

        .modules-right {
          font-size: 15px;
          background-color: #${config.colorScheme.palette.base00};
          border-radius: 10px;
          padding: 5px 10px;
          margin-top: 5px;
          margin-bottom: 5px;
          margin-right: 0.1rem;
        }

        .modules-left {
          font-size: 15px;
          margin-left: 10px;
          background-color: #${config.colorScheme.palette.base00};
          margin-top: 5px;
          margin-bottom: 5px;
          padding: 1px 0px;
          border-radius: 10px;
        }

        .modules-center {
          font-size: 15px;
          margin-left: 10px;
          background-color: #${config.colorScheme.palette.base00};
          margin-top: 5px;
          margin-bottom: 5px;
          padding: 5px 10px;
          border-radius: 10px;
        }

        tooltip {
          background: #${config.colorScheme.palette.base00};
          border-radius: 10px;
        }

        tooltip label {
          color: #${config.colorScheme.palette.base06};
          background-color: #${config.colorScheme.palette.base00};
          border-radius: 10px;
        }

        tooltip * {
          border-radius: 10px;
        }

        #workspaces {
          margin: 1px;
          margin-right: 0.3rem;
          margin-left: 0.3rem;
        }

        #workspaces button {
          margin: 1px;
          color: #${config.colorScheme.palette.base06};
          font-weight: bolder;
          font-style: normal;
          margin: 0.2rem 0.2rem;
          border-radius: 20px;
        }

        #workspaces button:hover {
          box-shadow: inherit;
          text-shadow: inherit;
          background-color: #${config.colorScheme.palette.base06};
          color: #${config.colorScheme.palette.base00};
          border-radius: 10px;
        }

        #workspaces button.active {
          color: #${config.colorScheme.palette.base06};
          background-color: rgba(125, 174, 163, 0.9);
          text-shadow: 0 0 5px rgba(0, 0, 0, 0.818);
          transition: all 0.1s ease-in-out;
          border-radius: 10px;
        }

        #clock {
          color: #${config.colorScheme.palette.base06};
        }

        #custom-power {
          font-size: 17px;
          margin: 10px;
          color: #${config.colorScheme.palette.base06};
          padding: 0 0.1em 0 0.1em;
        }

        #custom-monitor {
          font-size: 17px;
          margin: 10px;
          color: #${config.colorScheme.palette.base06};
          padding: 0 0.1em 0 0.1em;
        }
        
        #custom-quit, #custom-lock, #custom-reboot {
          font-size: 17px;
          color: #${config.colorScheme.palette.base06};
          margin: 10px;
          padding: 0 0.1em 0 0.1em;
        }

        #custom-updates {
          padding-left: 1rem;
        }

        #custom-spotify {
          padding: 0 0 0 1.5em;
          border-radius: 10 0 0 10;
        }
        #memory {
          color: #${config.colorScheme.palette.base06};
          padding: 0 0.3em 0 0.5em;
          border-radius: 10 0 0 10;
        }

        #pulseaudio {
          margin: 0;
          padding: 0 0.5em 0 0.4em;
          color: #${config.colorScheme.palette.base06};
        }

        #backlight {
          margin: 0;
          padding: 0 0.5em 0 0.4em;
          color: #${config.colorScheme.palette.base06};
        }

        #cpu {
          margin: 0;
          padding: 0 0.1em 0 0.1em;
          color: #${config.colorScheme.palette.base06};
        }

        #network {
          margin: 0;
          padding: 0 0.4em 0 0.5em;
          color: #${config.colorScheme.palette.base06};
        }

        #custom-cycle_wall {
          margin: 0;
          padding: 0 0.5em;
          color: #${config.colorScheme.palette.base06};
        }
        
        #idle_inhibitor {
          margin: 0;
          padding: 0 0.5em;
          color: #fe8019;
        }

        #language {
          margin: 0;
          padding: 0 0.1em;
          color: #${config.colorScheme.palette.base06};
        }

        #tray {
          margin: 0;
          padding-right: 10px;
          color: #${config.colorScheme.palette.base06};
          border-radius: 0 10 10 0;
        }

        #battery {
          margin: 0;
          padding: 0 0.5em 0 0.8em;
          color: #${config.colorScheme.palette.base06};
        }

        #disk {
          margin: 0;
          padding: 0 0.1em 0 0.1em;
          color:  #${config.colorScheme.palette.base06};
        }

        #cava {
          margin: 0;
          padding: 0 0.1em 0 0.1em;
          color:  #${config.colorScheme.palette.base06};
        }

        #window {
          color: #${config.colorScheme.palette.base06};
          margin-left: 1rem;
          margin-right: 1rem;
          text-shadow: 0 0 5px rgba(0, 0, 0, 0.818);
          transition: all 0.1s ease-in-out;
          border-radius: 0px;
          font-size: 15px;
        }
    '';
  };
}
