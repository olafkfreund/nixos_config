{
  pkgs,
  config,
  lib,
  ...
}: {
  programs.waybar = {
    enable = true;
    package = pkgs.waybar;
    settings = {
      mainBar = {
        "layer" = "top";
        "position" = "top";
        "mod" = "dock";
        "margin-top" = 0;
        "margin-bottom" = 0;
        "margin-left" = 0;
        "margin-right" = 0;
        "spacing" = 4;
        "fixed-center" = true;
        "exclusive" = true;
        "passthrough" = false;
        "reload_style_on_change" = true;
        "gtk-layer-shell" = true;

        "modules-left" = [
          "hyprland/workspaces"
          "hyprland/window"
        ];

        "modules-right" = [
          "network"
          "bluetooth"
          "custom/swaync"
          "power-profiles-daemon"
          "cpu"
          "memory"
          "idle_inhibitor"
          "pulseaudio"
          # "pulseaudio#microphone"
          "battery"
          "clock"
          # "custom/weather"
          "custom/powermenu"
        ];

        "modules-center" = [
          # "clock"
        ];

        "memory" = {
          interval = 10;
          format = "   {}% ";
          max-length = 20;
        };

        "cpu" = {
          interval = 1;
          format = "   {usage}% ";
        };

        "custom/cycle_wall" = {
          format = " 󰡼 ";
          on-click = "waypaper";
        };

        "idle_inhibitor" = {
          format = " {icon}";
          format-icons = {
            activated = "󱐋 ";
            deactivated = "󰤄 ";
          };
        };

        "custom/monitor" = {
          format = " 󱋆 ";
          on-click = "${pkgs.wdisplays}/bin/wdisplays";
        };

        "hyprland/workspaces" = {
          format = "{icon}";
          show-special = true;
          on-click = "active";
          active-only = false;
          on-scroll-up = "${pkgs.hyprland}/bin/hyprctl dispatch workspace e-1";
          on-scroll-down = "${pkgs.hyprland}/bin/hyprctl dispatch workspace e+1";
          max-length = 45;
          persistent-workspaces = {
            "spotify" = [
              "*"
            ];
            "mail" = [
              "*"
            ];
            "tmux" = [
              "*"
            ];
            "slack" = [
              "*"
            ];
          };
          "format-icons" = {
            "1" = "1";
            "2" = "2";
            "3" = "3";
            "4" = "4";
            "5" = "5";
            "6" = "6";
            "7" = "7";
            "8" = "8";
            "9" = "9";
            "10" = "10";
            "magic" = "󱕴";
            "hidden" = "󰐃";
            "secret" = "󱕴";
            "spotify" = " ";
            "slack" = " ";
            "mail" = " ";
            "tmux" = " ";
          };
        };

        "hyprland/window" = {
          icon = true;
          format = "{title}";
          max-length = 100;
        };

        "tray" = {
          spacing = 5;
          show-passive-items = true;
        };

        "custom/tailscale" = {
          exec = "info-tailscale";
          on-click = "choose_vpn_config";
          restart-interval = 1;
        };

        clock = {
          format = "  {:%a %d-%m %H:%M} ";
          tooltip = true;
          format-alt = "{:%A, %B %d, %Y}";
          max-lenght = 25;
          interval = 60;
          on-click = "gnome-calendar";
          on-left-click = "notify-send \"Date / Time\" \"󰃭 $(date \"+%a %h %d\")   $(date \"+%I:%M %p\")\"";
        };

        "battery" = {
          states = {
            good = 80;
            warning = 30;
            critical = 20;
          };
          format = " {icon} ";
          format-charging = " {capacity}% 󰂄 ";
          format-plugged = " {capacity}%  ";
          format-alt = "{time} ";
          format-icons = ["󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹"];
        };

        "custom/powermenu" = {
          format = " ";
          on-click = "pmenu";
          tooltip = false;
        };

        "network" = {
          format = "{ifname} {ipaddr} ";
          format-wifi = "󰖩 ";
          format-ethernet = "󰈀 ";
          tooltip-format = "{ipaddr}  {bandwidthUpBytes}  {bandwidthDownBytes}";
          format-linked = "{ifname} (No IP)";
          format-disconnected = " 󰌙 ";
          format-alt = "{signalStrength}% ";
          on-click = "${pkgs.networkmanager}/bin/nmtui";
        };

        "bluetooth" = {
          format = " 󰂯 ";
          format-on = " 󰂯 ";
          format-off = "";
          format-disabled = ""; # an empty format will hide the module
          format-connected = "  {num_connections} ";
          on-click = "${pkgs.bluetuith}/bin/bluetuith --color dark";
        };

        "pulseaudio" = {
          format = " {icon} {volume}% ";
          format-bluetooth = " {icon} {volume}% ";
          format-muted = "婢";
          on-click = "pavucontrol -t 3";
          tooltip-format = " {icon} {desc} // {volume}%";
          scroll-step = 1;
          format-icons = {
            car = "";
            default = ["" " " " "];
            headphones = "";
            headset = "";
          };
        };

        "custom/weather" = {
          exec = "weather London";
          return-type = "json";
          format = " {} ";
          tooltip = true;
          interval = 3600;
        };

        "temperature" = {
          format = "{temperature}°C   ";
          tooltip-format = "{temperature}°C ";
          interval = 10;
        };

        "power-profiles-daemon" = {
          format = " {icon} ";
          tooltip-format = "Power profile: {profile}\nDriver: {driver}";
          tooltip = true;
          format-icons = {
            default = " ";
            performance = " ";
            balanced = " ";
            power-saver = " ";
          };
        };

        "sway/mode" = {
          format = "<span style=\"italic\">{}</span>";
        };
        
        "sway/scratchpad" = {
          format = "{icon} {count}";
          show-empty = false;
          format-icons = ["" ""];
          tooltip = true;
          tooltip-format = "{app}: {title}";
        };

        "wlr/workspaces" = {
          on-click = "activate";
        };

        "custom/swaync" = {
          format = " ";
          on-click = "${pkgs.swaynotificationcenter}/bin/swaync-client -t";
          on-click-right = "${pkgs.swaynotificationcenter}/bin/swaync-client -C";
          on-click-middle = "notify_count";
          tooltip = false;
        };

        "pulseaudio#microphone" = {
          format = " {icon} {format_source} ";
          format-source = " {volume}% ";
          format-source-muted = " ";
          on-click = "${pkgs.pavucontrol}/bin/pavucontrol -t 4";
          tooltip-format = "{format_source} {source_desc} // {source_volume}%";
          scroll-step = 5;
        };

        "custom/cal" = {
          format = "  ";
          tooltip = false;
        };

        "custom/nix-updates" = {
          exec = "update-checker";
          on-click = "update-checker && notify-send 'The system has been updated'";
          interval = 3600;
          tooltip = true;
          return-type = "json";
          format = "{icon} {} ";
          format-icons = {
            has-updates = " ";
            updated = " ";
          };
        };
      };
    };

    style = ''
      * {
        font-family: 'JetBrainsMono Nerd Font FontAwesome Roboto Helvetica Arial sans-serif';
        font-size: 14px;
        font-weight: bolder;
        }

        window#waybar {
          background-color: #1f2223;
          border-bottom: 8px solid #191c1d;
          color:  #ebdbb2;
          transition-property: background-color;
          transition-duration: .5s;
        }

        .modules-left > widget:first-child > #workspaces {
            margin-left: 0;
        }

        .modules-right > widget:last-child > #workspaces {
            margin-right: 0;
        }

        .modules-center {
          background-color: transparent;
        }

        tooltip {
          background-color: #1f2223;
          border: none;
          border-bottom: 8px solid #191c1d;
          border-left: 6px solid #191c1d;
          border-radius: 5px;
        }

        tooltip decoration {
          box-shadow: none;
        }

        tooltip decoration:backdrop {
          box-shadow: none;
        }

        tooltip label {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 16px;
          padding-left: 5px;
          padding-right: 5px;
          padding-top: 0px;
          padding-bottom: 5px;
        }

        #scratchpad {
            background: rgba(0, 0, 0, 0.2);
        }

        #scratchpad.empty {
          background-color: transparent;
        }

        #workspaces {
           margin: 0 4px;
        }

        #workspaces button {
          all: unset;
          border: none;
          border-bottom: 8px solid #518554;
          border-left: 6px solid #518554;
          border-radius: 5px;
          margin-left: 4px;
          margin-bottom: 2px;
          font-family: JetBrainsMono Nerd Font, sans-sherif;
          font-weight: bold;
          font-size: 14px;
          padding-left: 13px;
          padding-right: 13px;
          transition: transform 0.1s ease-in-out;
          color: #282828;
          background-color: #689d6a;
        }

        #workspaces button:hover {
          background: inherit;
          background-color: #8ec07c;
          border-bottom: 8px solid #76a765;
          border-left: 6px solid #76a765;
        }

        #workspaces button.active {
          background: inherit;
          background-color: #7db37e;
          border-bottom: 8px solid  #659a68;
          border-left: 6px solid  #659a68;
        }

        #custom-weather {
          background-color:  #5d9da0;
          color: #282828;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 15px;
          font-weight: bold;
          border: none;
          border-bottom: 8px solid #458588;
          border-left: 6px solid #458588;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #clock {
          background-color: #5d9da0;
          color: #282828;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-bottom: 8px solid #458588;
          border-left: 6px solid #458588;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #custom-swaync {
          background-color: #ec7024;
          color:  #282828;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-bottom: 8px solid #d05806;
          border-left: 6px solid #d05806;
          border-radius: 5px;
          margin-bottom: 2px;
          padding-left: 12px;
          padding-right: 9px;
        }

        #power-profiles-daemon {
          background-color:  #689d6a;
          color: #282828;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-bottom: 8px solid  #518554;
          border-left: 6px solid  #518554;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #pulseaudio {
          background-color: #f2b13c;
          color: #282828;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-bottom: 8px solid  #d79921;
          border-left: 6px solid  #d79921;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #pulseaudio.microphone {
          background-color: #f2b13c;
          color: #282828;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-bottom: 8px solid  #d79921;
          border-left: 6px solid  #d79921;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #pulseaudio.muted {
          background-color: #f2b13c;
          color: #e23c2c;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-bottom: 8px solid  #d79921;
          border-left: 6px solid  #d79921;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #network {
          background-color: #ec7024;
          color:  #282828;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-bottom: 8px solid #d05806;
          border-left: 6px solid #d05806;
          border-radius: 5px;
          margin-bottom: 2px;
          padding-left: 12px;
          padding-right: 9px;
          
        }

        #idle_inhibitor {
          background-color: #f2b13c;
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-bottom: 8px solid #d79921;
          border-left: 6px solid #d79921;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #idle_inhibitor.activated {
          background-color: #f2b13c;
          color: #282828;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-bottom: 8px solid #d79921;
          border-left: 6px solid #d79921;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #tray {
          background-color: #ec7024;
          color: #282828;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-bottom: 8px solid #d05806;
          border-left: 6px solid #d05806;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #tray > .passive {
            -gtk-icon-effect: dim;
        }

        #tray > .needs-attention {
            -gtk-icon-effect: highlight;
            background-color: #eb4d4b;
        }

        #battery {
          background-color: #5d9da0;
          color: #282828;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-bottom: 8px solid  #458588;
          border-left: 6px solid  #458588;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #cpu {
          background-color:  #689d6a;
          color: #282828;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-bottom: 8px solid  #518554;
          border-left: 6px solid  #518554;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #memory {
          background-color:  #689d6a;
          color: #282828;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-bottom: 8px solid  #518554;
          border-left: 6px solid  #518554;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #custom-powermenu {
          background-color: #e23c2c;
          color: #282828;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-bottom: 8px solid #cc241d;
          border-bottom: 6px solid #cc241d;
          border-radius: 5px;
          margin-bottom: 2px;
          margin-right: 4px;
          padding-left: 14px;
          padding-right: 7px;
        }

        #window {
          background-color: #303030;
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-bottom: 8px solid #252c32;
          border-left: 6px solid #252c32;
          border-radius: 5px;
          margin-bottom: 2px;
          padding-left: 10px;
          padding-right: 10px;
        }

        #bluetooth {
          background-color: #ec7024;
          color: #282828;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-bottom: 8px solid #d05806;
          border-left: 6px solid #d05806;
          border-radius: 5px;
          margin-bottom: 2px;
        }
    '';
  };
}
