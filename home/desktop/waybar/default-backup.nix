{ pkgs
, config
, lib
, ...
}: {
  programs.waybar = {
    enable = true;
    package = pkgs.waybar;
    settings = {
      mainBar = {
        "layer" = "top";
        "position" = "bottom"; #"top";
        "mod" = "dock";
        "margin-top" = 0;
        "margin-bottom" = 0;
        "margin-left" = 0;
        "margin-right" = 0;
        "spacing" = 0;
        "fixed-center" = true;
        "exclusive" = true;
        "passthrough" = false;
        "reload_style_on_change" = true;
        "gtk-layer-shell" = true;

        "modules-left" = [
          # "hyprland/workspaces"
          "hyprland/window"

        ];

        "modules-right" = [
          "group/system"
          # "idle_inhibitor#icons"
          "idle_inhibitor"
          "custom/cal"
          "clock"
          "group/computer"
          "tray"
        ];

        "modules-center" = [
          "hyprland/workspaces"
          # "hyprland/window"
          # "custom/weather"
        ];

        "custom/settings" = {
          format = " ";
          tooltip = false;
        };

        "custom/info" = {
          format = " 󰐖 ";
          tooltip = false;
        };

        "memory" = {
          interval = 1;
          rotate = 270;
          format = "{icon}";
          format-icons = ["󰝦" "󰪞" "󰪟" "󰪠" "󰪡" "󰪢" "󰪣" "󰪤" "󰪥"];
          max-length = 10;
        };

        "cpu" = {
            interval = 1;
            format = "{icon}";
            rotate = 270;
            format-icons = ["󰝦" "󰪞" "󰪟" "󰪠" "󰪡" "󰪢" "󰪣" "󰪤" "󰪥"];
        };

        "custom/cycle_wall" = {
          format = "󰸉 ";
          on-click = "waypaper";
          tooltip = true;
          tooltip-format = "Change wallpaper";
        };

        "idle_inhibitor#icons" = {
          format = "{icon}";
          format-icons = {
            activated = "󱐋";
            deactivated = "󰤄";
          };
        };

        "idle_inhibitor" = {
          format = "{icon} ";
          format-icons = {
            activated =  "󰥔";
            deactivated = "";
          };
        };
        "group/tray" = {
          orientation = "inherit";
          drawer = {
            transition-duration = 500;
            transition-left-to-right = false;
          };
          modules = [
            "custom/tray"
            "tray"
          ];
        };

        "custom/monitor" = {
          format = "󰹑 ";
          on-click = "${pkgs.wdisplays}/bin/wdisplays";
          tooltip = false;
        };

        "custom/tray" = {
          tooltip = false;
          format = "󱊔 ";
          on-click = "";
        };

        "hyprland/workspaces" = {
          # format = "{icon}: {windows}";
          format = "{icon}";
          show-special = true;
          on-click = "active";
          active-only = false;
          on-scroll-up = "${pkgs.hyprland}/bin/hyprctl dispatch workspace e-1";
          on-scroll-down = "${pkgs.hyprland}/bin/hyprctl dispatch workspace e+1";
          max-length = 45;
          window-rewrite = {
            "class<edge>" = " ";
            "class<google-chrome>" = " ";
            "class<slack>" = "󰒱 ";
            "class<thunderbird>" = " ";
            "class<kitty>" = " ";
            "class<Alacritty>" = " ";
            "class<1Password>" = "󰌾 ";
            "class<org.wezfurlong.wezterm>" = "󰆍 ";
            "class<org.gnome.Nautilus>" = " ";
            "class<ferdium>" = "󱐏 ";
            "class<firefox>" = " ";
            "class<cursor-url-handler>" = "󰨞 ";
            "class<foot>" = "󰆍 ";
            "title<Spotify Premium>" = " ";
            "tilte<nvim>" = " ";
            "class<neovide>" = " ";
            "class<obsidian>" = "󰠮 ";
            "Alacritty" = " ";
            "title<tmux>" = " ";
            "class<code-url-handler>" = "󰨞 ";
            "class<Podman Desktop>" = " ";

          };
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
            "default" = " ";
	          "active" = " ";
            # "active" = "󰻂 ";
            # "default" = " ";
            "urgent" = " ";
            "magic" = "󰟵 ";
            "mail" = " ";
            "tmux" = " ";
            "hidden" = " ";
            "slack" = " ";
            "secret" = " ";
            "spotify" = " ";
          };
        };

        "group/computer" = {
          orientation = "inherit";
          drawer = {
            transition-duration = 500;
            transition-left-to-right = true;
          };
          modules = [
            "custom/settings"
            "custom/cycle_wall"
            "custom/dunst"
            "custom/monitor"
            "custom/tailscale"
          ];
        };
        
        "group/system" = {
          orientation = "inherit";
          drawer = {
            transition-duration = 500;
            transition-left-to-right = true;
          };
          modules = [
            "custom/info"
            "network#icons"
            "network"
            "custom/nix-updates"
            "temperature"
            "custom/weather"
            "battery#icons"
            "battery"
            "power-profiles-daemon"
            "bluetooth#icons"
            "bluetooth"
            "pulseaudio#icons"
            "pulseaudio"
            "pulseaudio#microphoneicons"
            "pulseaudio#microphone"
          ];
        };

        "hyprland/window" = {
          icon = true;
          separate-outputs = true;
          rewrite = {
            ".+" = "";
          };
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
          format = "{:%H:%M} ";
          max-lenght = 25;
          min-length = 6;
          format-alt = "{:%A, %B %d, %Y (%R)} ";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "month";
            mode-mon-row = 2;
            mode-mon-col = 3;
            weeks-pos = "right";
            on-scroll = 1;
            on-click-right = "mode";
            format = {
              months = "<span color='#${config.colorScheme.palette.base05}'><b>{}</b></span>";
              days = "<span color='#${config.colorScheme.palette.base05}'><b>{}</b></span>";
              weeks = "<span color='#${config.colorScheme.palette.base05}'><b>W{}</b></span>";
              weekdays = "<span color='#${config.colorScheme.palette.base05}'><b>{}</b></span>";
              today = "<span color='#${config.colorScheme.palette.base05}'><b><u>{}</u></b></span>";
            };
          };
          actions = {
            on-click-right = "mode";
            on-click-forward = "tz_up";
            on-click-backward = "tz_down";
            on-scroll-up = "shift_up";
            on-scroll-down = "shift_down";
          };
        };

        "battery" = {
          states = {
            good = 80;
            warning = 30;
            critical = 20;
          };
          format = "{capacity}% ";
          format-charging = "{capacity}% ";
          format-plugged = "{capacity}% ";
          format-alt = "{time} ";
        };

        "battery#icons" = {
          format = "{icon}";
          format-charging = "";
          format-plugged = "";
          format-icons = [ "󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
        };

        "network#icons" = {
          format-ethernet = "󰈀 ";
          tooltip-format = "󰈀 ";
          format-wifi = "󰖩 ";
          format-linked = "󰈀 ";
          format-disconnected = "";
          format-alt = "󰖩 ";
        };

        "network" = {
          format-wifi = "{essid} ";
          format-ethernet = "{ipaddr} ";
          tooltip-format = "{ipaddr}  {bandwidthUpBytes}  {bandwidthDownBytes}";
          format-linked = "{ifname} (No IP)";
          format-disconnected = "Disconnected";
          format-alt = "{signalStrength}% ";
          on-click = "nm-connection-editor";
        };

        "bluetooth#icons" = {
          format = "{icon}";
          format-on = "";
          format-off = "󰂲";
          format-disabled = "󰂲"; # an empty format will hide the module
          format-connected = " {num_connections}";
        };

        "bluetooth" = {
          format = "{status}";
          format-connected = "{num_connections}";
          tooltip-format = "{device_alias}";
          tooltip-format-connected = "{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}";
          on-click = "foot bluetuith --color dark";
        };
        "pulseaudio#icons" = {
          format = "{icon}";
          format-bluetooth = "{icon}";
          format-muted = "婢";
          on-click = "pavucontrol -t 3";
          tooltip-format = "{icon} {desc} // {volume}%";
          scroll-step = 1;
          format-icons = {
            car = "";
            default = [ "" " " " " ];
            headphones = "";
            headset = "";
          };
        };

        "pulseaudio" = {
          format = "{volume}% ";
          format-bluetooth = "{volume}%";
          format-muted = "婢";
          format-icons = {
            car = "";
            default = [ "" " " " " ];
            headphones = "";
            headset = "";
          };
        };

        "custom/weathericons" = {
          format = " ";
          tooltip = false;
        };
        "custom/weather" = {
          exec = "weather London";
          return-type = "json";
          format = "{} ";
          tooltip = true;
          interval = 3600;
        };

        "temperature" = {
          hwmon = "/sys/devices/virtual/thermal/thermal_zone1/hwmon3/temp1_input";
          format = "{temperature}°C ";
          tooltip-format = "{temperature}°C ";
          interval = 10;
        };

        "power-profiles-daemon" = {
          "format" = "{icon} {profile}";
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
          format = "{format_source}";
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
          format = " ";
          tooltip = false;
        };
       "custom/nix-updates" = {
          "exec" = "update-checker";
          "on-click" = "update-checker && notify-send 'The system has been updated'";
          "interval" = 3600;
          "tooltip" = true;
          "return-type" = "json";
          "format" = "{} {icon} ";
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
        font-size: 15px;
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
          color: #${config.colorScheme.palette.base07};
          background-color: transparent;
          margin: 2px 2px 2px 2px;
          opacity: 1;
        }
        
        #workspaces button:hover {
          color: #${config.colorScheme.palette.base09};
          background-color: transparent;
          animation: tb_hover 20s ease-in-out 1;
          transition: all 0.3s cubic-bezier(.55,-0.68,.48,1.682);
          opacity: 1;
        }

        #workspaces button.active {
          color: #${config.colorScheme.palette.base0A};
          background-color: transparent;
          animation: tb_hover 20s ease-in-out 1;
          transition: all 0.1s ease-in-out;
          opacity: 1;
        }

        #workspaces button.urgent {
          color: #${config.colorScheme.palette.base08};
          background-color: transparent;
          transition: all 0.1s ease-in-out;
          animation: tb_hover 20s ease-in-out 1;
          opacity: 1;
        }

        #workspaces button.secret {
          color: #${config.colorScheme.palette.base08};
          background-color: transparent;
          transition: all 0.1s ease-in-out;
          animation: tb_hover 20s ease-in-out 1;
          min-height: 15px;
          font-size: 17px;
          opacity: 1;
        }

        #workspaces button.spotify {
          color: #${config.colorScheme.palette.base0B};
          background-color: transparent;
          transition: all 0.1s ease-in-out;
          animation: tb_hover 20s ease-in-out 1;
          margin: 2 2px; 
          padding: 5px;
          opacity: 1;
        }

        #custom-weathericons {
          margin: 0 0 0 2px;
          padding: 5px;
          color: #${config.colorScheme.palette.base05};
        }

        #custom-weather {
          margin: 0 2 0 0px;
          padding: 5px;
          background-color: transparent;
          color: #${config.colorScheme.palette.base05};
        }
        
        #custom-cal {
          margin: 0 0 0 5px; 
          padding: 5px;
          color: #${config.colorScheme.palette.base05};
        }

        #clock {
          color: #${config.colorScheme.palette.base05};
          margin: 0 5 0 0px;
        }
        
        #temperature {
          color: #${config.colorScheme.palette.base05};
          margin: 0 5 0 0px;
        }
        
        #privacy {
          color: #${config.colorScheme.palette.base05};
          margin: 0 5 0 0px;
        }

        #privacy-item {
          color: #${config.colorScheme.palette.base05};
          margin: 0 5 0 0px;
        }

        #power-profiles-daemon {
          color: #${config.colorScheme.palette.base05};
          margin: 0 5 0 0px;
        }

        #custom-nix-updates {
          color: #${config.colorScheme.palette.base05};
          margin: 0 5 0 0px;
        }

       #custom-startmenu {
          color: #${config.colorScheme.palette.base05};
          margin: 2 2px; 
          padding: 5px;
        }

        #custom-monitor {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base05};
        }

        #pulseaudio.icons {
          border: none;
          padding: 5px;
          margin: 0 0 0 0px;
          color: #${config.colorScheme.palette.base05};
        }

        #pulseaudio {
          border: none;
          padding: 5px;
          margin: 0 0 0 0px;
          color: #${config.colorScheme.palette.base05};
        }

        #pulseaudio.microphoneicons {
          padding: 5px;
          border: none;
          margin: 0 0 0 5px;
          color: #${config.colorScheme.palette.base05};
        }

        #pulseaudio.microphone {
          padding: 5px;
          border: none;
          margin: 0 2 0 0px;
          color: #${config.colorScheme.palette.base05};
        }

        #pulseaudio.muted {
          padding: 5px;
          border: none;
          margin: 0 2 0 0px;
          color: #${config.colorScheme.palette.base05};
        }

        #network.icons  {
          margin: 0 0 0 2px;
          border: none;
          padding: 5px;
          color: #${config.colorScheme.palette.base05};
        }

        #network {
          margin: 0 2 0 0px;
          border: none;
          padding: 5px;
          color: #${config.colorScheme.palette.base05};
        }

        #custom-cycle_wall {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base05};
        }

        #custom-tailscale {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base05};
        }

        #custom-dunst {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base05};
        }

        #custom-settings {
          padding: 0 5px;
          margin: 0 5 0 5px;
          color: #${config.colorScheme.palette.base05};
        }
        #custom-info {
          padding: 0 5px;
          margin: 0 5 0 5px;
          color: #${config.colorScheme.palette.base05};
        }
        #idle_inhibitor.icons {
          padding: 5px;
          border: none;
          margin: 0 0 0 2px;
          color: #${config.colorScheme.palette.base05};
        }

        #idle_inhibitor {
          padding: 5px;
          border: none;
          margin: 0 2 0 0px;
          color: #${config.colorScheme.palette.base05};
        }

        #tray {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base05};
        }

        #battery.icons {
          padding: 0 5px;
          border: none;
          margin: 0 0 0 2px;
          color: #${config.colorScheme.palette.base05};
        }
        #battery {
          padding: 0 5px;
          border: none;
          margin: 0 2 0 0px;
          color: #${config.colorScheme.palette.base05};
        }

        #window {
          color: #${config.colorScheme.palette.base05};
          transition: all 0.1s ease-in-out;
          margin: 0 2 0 2px;
          padding: 0 10px;
        }

        #image {
          color: #${config.colorScheme.palette.base05};
          margin: 0 0 0 2px;
          padding: 5px;
        }

        #custom-spotify {
          color: #${config.colorScheme.palette.base05};
          margin: 0 0 0 2px;
          padding: 5px;
        }
        #custom-playerctl {
          color: #${config.colorScheme.palette.base05};
          transition: all 0.1s ease-in-out;
          margin: 0 2 0 0px;
          padding: 5px;

        }

        #bluetooth.icons {
          padding: 5px;
          border: none;
          margin: 0 0 0 2px;
          color: #${config.colorScheme.palette.base05};
        }
        #bluetooth {
          padding: 5px;
          border: none;
          margin: 0 2 0 0px;
          color: #${config.colorScheme.palette.base05};
        }
    '';
  };
}
