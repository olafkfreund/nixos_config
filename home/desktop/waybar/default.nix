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
        "position" = "bottom";
        "mod" = "dock";
        "margin-top" = 2;
        "margin-bottom" = 2;
        "margin-left" = 2;
        "margin-right" = 2;
        "spacing" = 4;
        "fixed-center" = true;
        "exclusive" = true;
        "passthrough" = false;
        "reload_style_on_change" = true;
        "gtk-layer-shell" = true;

        "modules-left" = [
          "hyprland/workspaces"
          "sway/workspaces"
          "sway/scratchpad"
          "sway/mode"
          "hyprland/submap"
          # "temperature"
        ];

        "modules-right" = [
          "cpu"
          "memory"
          "temperature"
          "pulseaudio"
          "pulseaudio#microphone"
          # "bluetooth"
          "custom/swaync"
          "power-profiles-daemon"
          "network"
          "idle_inhibitor"
          "battery"
          "clock"
          # "custom/weather"
          # "custom/powermenu"
        ];

        "modules-center" = [
          # "hyprland/workspaces"
          # "sway/workspaces"
          # "sway/scratchpad"
          # "sway/mode"
        ];

        "memory" = {
          interval = 1;
          format = "{icon}";
          format-icons = ["▁▁" "▂▂" "▃▃" "▄▄" "▅▅" "▆▆" "▇▇" "██"];
          max-length = 20;
        };

        "cpu" = {
          interval = 1;
          format = "{icon}";
          format-icons = ["▁▁" "▂▂" "▃▃" "▄▄" "▅▅" "▆▆" "▇▇" "██"];
          max-length = 20;
        };

        "custom/cycle_wall" = {
          format = " 󰡼 ";
          on-click = "waypaper";
        };

        "idle_inhibitor" = {
          format = " {icon}";
          format-icons = {
            activated = "󰅶";
            deactivated = "󰾪";
          };
        };

        "hyprland/submap" = {
          format = "{}";
          max-length = 8;
          tooltip = false;
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
            "scratchpad" = " ";
          };
        };

        "sway/workspaces" = {
          format = "{icon}";
          show-special = true;
          on-click = "active";
          active-only = false;
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
            "11" = "󱕴";
            "16" = "󰐃";
            "12" = " ";
            "13" = " ";
            "14" = " ";
            "15" = " ";
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
          tooltip = false;
          # format-alt = "{:%A, %B %d, %Y}";
          max-lenght = 25;
          interval = 60;
          on-click = "gnome-calendar";
          # on-left-click = "notify-send \"Date / Time\" \"󰃭 $(date \"+%a %h %d\")   $(date \"+%I:%M %p\")\"";
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
          format = "{temperatureC}°C   ";
          hwmon-path = " /sys/devices/pci0000:00/0000:00:18.3/hwmon/hwmon2/temp1_input";
          tooltip-format = "{temperatureC}°C ";
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
          format = "{}";
          max-length = 50;
        };

        "sway/scratchpad" = {
          format = "{icon} {count}";
          show-empty = false;
          format-icons = ["" ""];
          tooltip = true;
          tooltip-format = "{app}: {title}";
        };

        # "wlr/workspaces" = {
        #   on-click = "activate";
        # };

        "custom/swaync" = {
          tooltip = false;
          format = "{icon}";
          format-icons = {
            "notification" = "󰅸";
            "none" = "󰂜";
            "dnd-notification" = "󰅸";
            "dnd-none" = "󱏨";
            "inhibited-notification" = "󰅸";
            "inhibited-none" = "󰂜";
            "dnd-inhibited-notification" = "󰅸";
            "dnd-inhibited-none" = "󱏨";
          };
          return-type = "json";
          exec-if = "which swaync-client";
          exec = "swaync-client -swb";
          on-click = "${pkgs.swaynotificationcenter}/bin/swaync-client -t";
          on-click-right = "${pkgs.swaynotificationcenter}/bin/swaync-client -C";
          on-click-middle = "notify_count";
          escape = true;
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
          background-color: #282828;
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
          background-color: #282828;
          border: none;
          border-bottom: 4px solid #ebdbb2;
          border-left: 4px solid #ebdbb2;
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
          border-bottom: 4px solid #ebdbb2;
          border-left: 4px solid #ebdbb2;
          border-top: 1px solid #ebdbb2;
          border-right: 1px solid #ebdbb2;
          border-radius: 5px;
          margin-left: 4px;
          margin-bottom: 2px;
          margin-top: 2px;
          font-family: JetBrainsMono Nerd Font, sans-sherif;
          font-weight: bold;
          font-size: 14px;
          padding-top: 4px;
          padding-bottom: 4px;
          padding-left: 13px;
          padding-right: 13px;
          transition: transform 0.1s ease-in-out;
          color: #ebdbb2;
          background-color: #282828;
        }

        #workspaces button:hover {
          color: #282828;
          background-color: #689d6a;
          border-bottom: 4px solid #ebdbb2;
          border-left: 4px solid #ebdbb2;
        }

        #workspaces button.active {
          color: #282828;
          background-color: #689d6a;
          border-bottom: 4px solid #ebdbb2;
          border-left: 4px solid #ebdbb2;
        }

        #custom-weather {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 15px;
          font-weight: bold;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #clock {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #custom-swaync {
          color:  #ebdbb2;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
          padding-left: 5px;
          padding-right: 5px;
        }

        #power-profiles-daemon {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #pulseaudio {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #pulseaudio.microphone {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #pulseaudio.muted {
          color: #e23c2c;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #network {
          color:  #ebdbb2;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
          padding-left: 5px;
          padding-right: 5px;

        }

        #idle_inhibitor {
          color: #fabd2f;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #idle_inhibitor.activated {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #tray {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
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
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #cpu {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 15px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #memory {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 15px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #custom-powermenu {
          background-color: #282828;
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-bottom: 4px solid #ebdbb2;
          border-left: 4px solid #ebdbb2;
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
          border-bottom: 4px solid #ebdbb2;
          border-left: 4px solid #ebdbb2;
          border-radius: 5px;
          margin-bottom: 2px;
          padding-left: 10px;
          padding-right: 10px;
        }

        #bluetooth {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font, monospace;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }
    '';
  };
}
