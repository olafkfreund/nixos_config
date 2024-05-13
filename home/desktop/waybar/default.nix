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
        "margin-left" = 100;
        "margin-right" = 100;
        "spacing" = 0;
        "fixed-center" = false;
        "exclusive" = true;
        "passthrough" = false;
        #"mode" = "dock";
        "reload_style_on_change" = true;
        "gtk-layer-shell" = true;

        "modules-left" = ["custom/startmenu" "custom/arrow11" "hyprland/workspaces" "custom/arrow10" ];
        "modules-right" = [
          "custom/arrow5"
          "group/monitor"
          "custom/arrow6"
          "pulseaudio"
          "pulseaudio#microphone"
          "custom/arrow7"
          "group/computer"
          "custom/arrow9"
          "idle_inhibitor"
          "custom/arrow4"
          "clock"
          ];
       "modules-center" = [ "cava" ];

        "custom/cycle_wall" = {
          "format" = " ";
          "on-click" = "wallpaper_picker";
          "tooltip" = true;
          "tooltip-format" = "Change wallpaper";
        };
        "idle_inhibitor" = {
          "format" = "{icon}";
          "format-icons" = {
            "deactivated" = "󰒲  ";
            "activated" = "󰒳  ";
          };
        };
        "cava"= {
            "framerate" = 30;
            "autosens" = 0;
            "sensitivity" = 120;
            "bars" = 30;
            "lower_cutoff_freq" = 50;
            "higher_cutoff_freq" = 10000;
            "method" = "pipewire";
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
              "on-click-right" = "mode";
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
          format = " ";
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
            "1" = "󰇩 ";
            "2" = "󰨞 ";
            "3" = " ";
            "4" = " ";
            "5" = " ";
            "6" = "";
            "7" = " ";
            "8" = " ";
            "9" = " ";
            "10" = "󰭹";
            # "active" = " ";
            "default" = " ";
            "urgent" = " ";
            "magic" = "󱡄 ";
            "hidden" = "󰐃 ";
            "secret" = " ";
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
          exec = "~/.config/waybar/scripts/dunst.sh";
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
          "format-ethernet" = "󰈀 ";
          "tooltip-format" = "󰈀 {ipaddr}  {bandwidthUpBytes}  {bandwidthDownBytes}";
          "format-linked" = "󰈀 {ifname} (No IP)";
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

          "custom/arrow1" = {
	       	"format" = "";
		      "tooltip"= false;
	        };

        	"custom/arrow2" = {
		      "format"= "";
		      "tooltip"= false;
	        };

	        "custom/arrow3" =  {
		      "format"= "";
		      "tooltip"= false;
	        };

          "custom/arrow4" = {
		      "format"= "";
		      "tooltip"= false;
	        };

	        "custom/arrow5" = {
		      "format" = "";
		      "tooltip" = false;
	        };

          "custom/arrow6" = {
		      "format" = "";
		      "tooltip" = false;
	        };

	        "custom/arrow7" = {
		      "format" = "";
		      "tooltip" = false;
	        };

	        "custom/arrow8" = {
          "format" = "";
          "tooltip" = false;
          };

          "custom/arrow9" = {
          "format" = "";
          "tooltip" = false;
          };

          "custom/arrow10" = {
          "format" = "";
          "tooltip" = false;
          };

          "custom/arrow11" = {
          "format" = "";
          "tooltip" = false;
          };
      };
    };

    style = ''
      * {
        font-family: 'JetBrainsMono';
        font-size: 20px;
        border: none;
        border-radius: 0;
        margin: 0;
        margin-right: 0;
        margin-left: 0;
        }

        window#waybar {
          background-color: #${config.colorScheme.palette.base00};
          font-size: 20px;
        }

        .modules-right {
          font-size: 20px;
          background-color: #${config.colorScheme.palette.base00};
        }

        .modules-left {
          font-size: 20px;
          
        }

        .modules-center {
          font-size: 20px;
          background-color: #${config.colorScheme.palette.base00};
        }

        tooltip {
          background: #${config.colorScheme.palette.base00};
          font-size: 20px;
        }

        tooltip label {
          color: #${config.colorScheme.palette.base06};
          background-color: #${config.colorScheme.palette.base00};
        }

        tooltip * {
        }

        #workspaces {
          padding: 0 0px;
          background-color: #${config.colorScheme.palette.base0D};
          font-size: 20px;
        }

        #workspaces button {
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base0D};
          font-weight: normal;
          font-style: normal;
          font-size: 20px;
        }
        
        #custom-arrow10 {
          font-size: 25px;
          border-radius: 0;
          border: none;
          color: #${config.colorScheme.palette.base0D};
          background-color: #${config.colorScheme.palette.base00};
          
        }

        #workspaces button:hover {
          box-shadow: inherit;
          text-shadow: inherit;
          background-color: #${config.colorScheme.palette.base06};
          color: #${config.colorScheme.palette.base09};
        }

        #workspaces button.active {
          color: #${config.colorScheme.palette.base09};
          background-color: #${config.colorScheme.palette.base0D};
          text-shadow: 0 0 5px rgba(0, 0, 0, 0.818);
          transition: all 0.1s ease-in-out;
        }

        #workspaces button.urgent {
          color: #${config.colorScheme.palette.base08};
          text-shadow: 0 0 5px rgba(0, 0, 0, 0.818);
          transition: all 0.1s ease-in-out;
        }
        #workspaces button.secret {
          color: #${config.colorScheme.palette.base08};
          text-shadow: 0 0 5px rgba(0, 0, 0, 0.818);
          transition: all 0.1s ease-in-out;
        }

        #workspaces button.urgent {
          color: #${config.colorScheme.palette.base08};
          text-shadow: 0 0 5px rgba(0, 0, 0, 0.818);
          transition: all 0.1s ease-in-out;
        }
        
        #clock {
          font-size: 20px;
          font-weight: bolder;
          font-style: normal;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base06};
        }
        #custom-arrow4 {
          font-size: 25px;
          color: #${config.colorScheme.palette.base06};
          background-color: #${config.colorScheme.palette.base0E};
          
        }

        #custom-startmenu {
          font-size: 20px;
          font-weight: bolder;
          font-style: normal;
          color: #${config.colorScheme.palette.base0D};
          background-color: #${config.colorScheme.palette.base00};
        }

        #custom-arrow11 {
          font-size: 25px;
          border-radius: 0;
          border: none;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base0D};
          
        }

        #custom-power {
          font-size: 20px;
          font-weight: bolder;
          font-style: normal;
          color: #${config.colorScheme.palette.base0D};
        }

        #custom-monitor {
          font-size: 20px;
          font-weight: bolder;
          font-style: normal;
          padding: 0 5px;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base0B};
        }

        #custom-arrow5 {
          font-size: 25px;
          color: #${config.colorScheme.palette.base08};
          background-color: #${config.colorScheme.palette.base00};
          
        }

        #custom-arrow7 {
          font-size: 25px;
          color: #${config.colorScheme.palette.base0B};
          background-color: #${config.colorScheme.palette.base0A};
          
        }
        
        #custom-quit, #custom-lock, #custom-reboot {
          font-size: 20px;
          font-weight: bolder;
          font-style: normal;
          color: #${config.colorScheme.palette.base0D};
        }

        #custom-spotify {
          padding: 0 5px;
        }
        #memory {
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base08};
          padding: 0 5px;
        }

        #pulseaudio {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base0A};
        }

        #pulseaudio#microphone {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base0A};
        }

        #pulseaudio.muted {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base0A};
        }

        #custom-arrow6 {
          color: #${config.colorScheme.palette.base0A};
          background-color: #${config.colorScheme.palette.base08};
          font-size: 25px;
        }

        #backlight {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base09};
        }

        #cpu {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base08};
        }

        #network {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base08};
        }

        #custom-cycle_wall {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base0B};
        }
        
        #idle_inhibitor {
          padding: 0 5px; 
          font-weight: bolder;
          font-style: normal;
          color: #${config.colorScheme.palette.base06};
          background-color: #${config.colorScheme.palette.base0E};
        }

        #idle_inhibitor.activated {
          padding: 0 5px;
          font-size: 20px;
          font-weight: bolder;
          font-style: normal;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base0E};
        }

        #custom-arrow9 {
          font-size: 25px;
          color: #${config.colorScheme.palette.base0E};
          background-color: #${config.colorScheme.palette.base0B};
          
        }

        #language {
          color: #${config.colorScheme.palette.base06};
        }

        #tray {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base06};
        }

        #battery {
          padding: 0 0.5px 0 0.8px;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base08};
        }

        #disk {
          padding: 0 0.1px 0 0.1px;
          color:  #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base08};
        }

        #cava {
          padding: 0 0.1px 0 0.1px;
          color:  #${config.colorScheme.palette.base09};
        }

        #window {
          color: #${config.colorScheme.palette.base06};
          text-shadow: 0 0 5px rgba(0, 0, 0, 0.818);
          transition: all 0.1s ease-in-out;
          font-size: 20px;
        }
    '';
  };
}
