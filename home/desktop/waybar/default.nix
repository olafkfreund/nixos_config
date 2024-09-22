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
          "temperature"
          "cpu"
          "memory"
          "network"
          "battery"
          "power-profiles-daemon"
          "bluetooth"
          "pulseaudio#icons"
          "pulseaudio"
          "pulseaudio#microphoneicons"
          "pulseaudio#microphone"
          "clock"
          "tray"
        ];

        "modules-center" = [
          "idle_inhibitor"
          "custom/weather"
        ];

        "memory" = {
          interval = 10;
          format = "   {used:0.1f}G/{total:0.1f}G ";
          max-length = 20;
        };

        "cpu" = {
          interval = 1;
          format = "   {}% ";
        };

        "custom/cycle_wall" = {
          format = " 󰡼 ";
          on-click = "waypaper";
        };

        "idle_inhibitor" = {
          format = "{icon}";
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
            "1" = [
              "DP-1"
            ];
            "2" = [
              "DP-1"
            ];
            "3" = [
              "DP-1"
            ];
            "4" = [
              "DP-1"
            ];
            "5" = [
              "DP-1"
            ];
            "11" = [
              "eDP-1"
            ];
            "12" = [
              "eDP-1"
            ];
            "13" = [
              "eDP-1"
            ];
            "14" = [
              "eDP-1"
            ];
            "15" = [
              "eDP-1"
            ];
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
            # "active" = " ";
            # "default" = "";
            # "urgent" = "";
            "magic" = "";
            "hidden" = "󰐃";
            "secret" = "";
            "spotify" = " ";
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

        "custom/dunst" = {
          exec = "dunst-waybar";
          on-click = "dunstctl set-paused toggle";
          restart-interval = 1;
        };

        "custom/tailscale" = {
          exec = "info-tailscale";
          on-click = "choose_vpn_config";
          restart-interval = 1;
        };

        clock = {
          format = "  {:%a %d-%m 󰥔 :%H:%M} ";
          max-lenght = 25;
          interval = 60;
          on-click = "gnome-calendar";
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

        "network" = {
          format = "{ifname} {ipaddr} ";
          format-wifi = " 󰖩 ";
          format-ethernet = " 󰈀 ";
          tooltip-format = "{ipaddr}  {bandwidthUpBytes}  {bandwidthDownBytes}";
          format-linked = "{ifname} (No IP)";
          format-disconnected = " 󰌙 ";
          format-alt = "{signalStrength}% ";
          on-click = "nmtui";
        };

        "bluetooth" = {
          format = " 󰂯 ";
          format-on = " 󰂯 ";
          format-off = " 󰂲 ";
          format-disabled = ""; # an empty format will hide the module
          format-connected = "  {num_connections} ";
          on-click = "foot bluetuith --color dark";
        };

        "pulseaudio#icons" = {
          format = " {icon} ";
          format-bluetooth = "{icon}";
          format-muted = "婢";
          on-click = "pavucontrol -t 3";
          tooltip-format = "{icon} {desc} // {volume}%";
          scroll-step = 1;
          format-icons = {
            car = "";
            default = ["" " " " "];
            headphones = "";
            headset = "";
          };
        };

        "pulseaudio" = {
          format = "{volume}% ";
          format-bluetooth = "{volume}% ";
          format-muted = "婢";
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
          hwmon-path = "/sys/devices/virtual/thermal/thermal_zone1/hwmon6/temp1_input";
          format = "{temperature}°C  | ";
          tooltip-format = "{temperature}°C ";
          interval = 10;
        };

        "power-profiles-daemon" = {
          "format" = " {icon} ";
          "tooltip-format" = "Power profile: {profile}\nDriver: {driver}";
          "tooltip" = true;
          "format-icons" = {
            "default" = "";
            "performance" = "";
            "balanced" = "";
            "power-saver" = "";
          };
        };

        "pulseaudio#microphoneicons" = {
          format = " {format_source} ";
          format-source = "";
          format-source-muted = " ";
        };

        "pulseaudio#microphone" = {
          format-source = "{volume}% ";
          on-click = "pavucontrol -t 4";
          tooltip-format = "{format_source} {source_desc} // {source_volume}%";
          scroll-step = 5;
        };

        "custom/cal" = {
          format = "  ";
          tooltip = false;
        };

        "custom/nix-updates" = {
          "exec" = "update-checker";
          "on-click" = "update-checker && notify-send 'The system has been updated'";
          "interval" = 3600;
          "tooltip" = true;
          "return-type" = "json";
          "format" = "{icon} {} ";
          "format-icons" = {
            "has-updates" = " ";
            "updated" = " ";
          };
        };
      };
    };

    style = ''
      * {
        font-family: 'Jetbrains Mono Nerd Font';
        font-size: 12px;
        font-weight: bolder;
        }

        window#waybar {
          background-color: #${config.colorScheme.palette.base00};
        }

        .modules-right {
          background-color: transparent;
        }

        .modules-left {
          background-color: transparent;
        }

        .modules-center {
          background-color: transparent;
        }

        tooltip {
         background-color: transparent;
        }

        tooltip label {
          color: #${config.colorScheme.palette.base05};
          background-color: transparent;
        }

        tooltip * {
        }

        #workspaces {
          background-color: transparent;
        }

        #workspaces button {
          all: unset;
          border: none;
          border-bottom: 8px solid #518554;
          border-radius: 5px;
          margin-left: 4px;
          margin-bottom: 2px;
          font-family: JetBrainsMono Nerd Font, sans-sherif;
          font-weight: bold;
          font-size: 12px;
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
        }

        #workspaces button.active {
        background: inherit;
        background-color: #7db37e;
        border-bottom: 8px solid  #659a68;
        }

        #workspaces button.urgent {
          color: #${config.colorScheme.palette.base08};
          background-color: transparent;
          opacity: 1;
        }

        #workspaces button.secret {
          color: #${config.colorScheme.palette.base08};
          background-color: transparent;
          min-height: 12px;
          font-size: 12px;
          opacity: 1;
        }

        #workspaces button.spotify {
          color: #${config.colorScheme.palette.base0B};
          background-color: transparent;
          margin: 2 2px;
          padding: 5px;
          opacity: 1;
        }

        #custom-weathericons {
          color: #${config.colorScheme.palette.base05};
        }

        #custom-weather {
          background-color: transparent;
          color: #${config.colorScheme.palette.base05};
        }

        #custom-cal {
          color: #${config.colorScheme.palette.base05};
        }

        #clock {
          color: #${config.colorScheme.palette.base05};
        }

        #temperature {
          color: #${config.colorScheme.palette.base05};
        }

        #privacy {
          color: #${config.colorScheme.palette.base05};
        }

        #privacy-item {
          color: #${config.colorScheme.palette.base05};
        }

        #power-profiles-daemon {
          color: #${config.colorScheme.palette.base05};
        }

        #custom-nix-updates {
          color: #${config.colorScheme.palette.base05};
        }

       #custom-startmenu {
          color: #${config.colorScheme.palette.base05};
        }

        #custom-monitor {
          color: #${config.colorScheme.palette.base05};
        }

        #pulseaudio.icons {
          color: #${config.colorScheme.palette.base05};
        }

        #pulseaudio {
          color: #${config.colorScheme.palette.base05};
        }

        #pulseaudio.microphoneicons {
          color: #${config.colorScheme.palette.base05};
        }

        #pulseaudio.microphone {
          color: #${config.colorScheme.palette.base05};
        }

        #pulseaudio.muted {
          color: #${config.colorScheme.palette.base08};
        }

        #network.icons  {
          color: #${config.colorScheme.palette.base05};
        }

        #network {
          color: #${config.colorScheme.palette.base05};
        }

        #custom-cycle_wall {
          color: #${config.colorScheme.palette.base05};
        }

        #custom-tailscale {
          color: #${config.colorScheme.palette.base05};
        }

        #custom-dunst {
          color: #${config.colorScheme.palette.base05};
        }

        #custom-settings {
          color: #${config.colorScheme.palette.base05};
        }

        #custom-info {
          color: #${config.colorScheme.palette.base05};
        }

        #idle_inhibitor.icons {
          color: #${config.colorScheme.palette.base05};
        }

        #idle_inhibitor {
          color: #${config.colorScheme.palette.base05};
        }

        #tray {
          color: #${config.colorScheme.palette.base05};
        }

        #battery {
          color: #${config.colorScheme.palette.base05};
        }

        #cpu {
          color: #${config.colorScheme.palette.base05};
        }

        #memory {
          color: #${config.colorScheme.palette.base05};
        }

        #window {
          border-radius: 20px;
          padding-left: 10px;
          padding-right: 10px;
          color: #${config.colorScheme.palette.base09};
          transition: all 0.1s ease-in-out;
        }

        #image {
          color: #${config.colorScheme.palette.base05};
          margin: 0 0 0 2px;
        }

        #custom-spotify {
          color: #${config.colorScheme.palette.base05};
          margin: 0 0 0 2px;
          padding: 5px;
        }

        #custom-playerctl {
          color: #${config.colorScheme.palette.base05};
          transition: all 0.1s ease-in-out;
        }

        #bluetooth.icons {
          color: #${config.colorScheme.palette.base05};
        }

        #bluetooth {
          color: #${config.colorScheme.palette.base05};
        }
    '';
  };
}
