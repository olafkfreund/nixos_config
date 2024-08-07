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
        "margin-top" = 10;
        "margin-bottom" = 3;
        "margin-left" = 20;
        "margin-right" = 20;
        "spacing" = 0;
        "fixed-center" = true;
        "exclusive" = true;
        "passthrough" = false;
        "reload_style_on_change" = true;
        "gtk-layer-shell" = true;

        "modules-left" = [
          # "hyprland/workspaces"
          # "hyprland/window"
          "image"
          "custom/playerctl"

        ];

        "modules-right" = [
          "custom/nix-updates"
          "custom/weather"
          "network#icons"
          "network"
          "battery#icons"
          "battery"
          "bluetooth#icons"
          "bluetooth"
          "pulseaudio#icons"
          "pulseaudio"
          "pulseaudio#microphoneicons"
          "pulseaudio#microphone"
          "idle_inhibitor#icons"
          "idle_inhibitor"
          "custom/cal"
          "clock"
          "group/computer"
        ];

        "modules-center" = [
          "hyprland/workspaces"
          "hyprland/window"
          # "image"
          # "custom/playerctl"
        ];

        "image" = {
          exec = "album_art";
          path = "/tmp/cover.jpeg";
          size = 20;
          interval = 5;
          on-click = "wezterm start --always-new-process -- bash -c spotify_player";
        };

        "custom/settings" = {
          format = " |";
          tooltip = false;
        };

        "custom/cycle_wall" = {
          format = "󰸉 |";
          on-click = "wallpaper_picker";
          tooltip = true;
          tooltip-format = "Change wallpaper";
        };

        "idle_inhibitor#icons" = {
          format = "| {icon}";
          format-icons = {
            activated = "󱐋";
            deactivated = "󰤄";
          };
        };

        "idle_inhibitor" = {
          format = "{icon} |";
          format-icons = {
            activated = "on";
            deactivated = "off";
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
          format = "󰹑 |";
          on-click = "${pkgs.wdisplays}/bin/wdisplays";
          tooltip = false;
        };

        "custom/tray" = {
          tooltip = false;
          format = "󱊖 ";
          on-click = "";
        };

        "hyprland/workspaces" = {
          format = "{icon}";
          show-special = true;
          on-click = "active";
          on-scroll-up = "${pkgs.hyprland}/bin/hyprctl dispatch workspace e-1";
          on-scroll-down = "${pkgs.hyprland}/bin/hyprctl dispatch workspace e+1";
          max-length = 45;
          persistent-workspaces = {
            "1" = [ ];
            "2" = [ ];
            "3" = [ ];
            "4" = [ ];
            "5" = [ ];
          };
          "format-icons" = {
            "1" = "󰲠 ";
            "2" = "󰲢 ";
            "3" = "󰲤 ";
            "4" = "󰲦 ";
            "5" = "󰲨 ";
            "6" = "󰲪 ";
            "7" = "󰲬 ";
            "8" = "󰲮 ";
            "9" = "󰲰 ";
            "10" = "󰿬 ";
            "active" = "󰻂 ";
            "default" = " ";
            "urgent" = " ";
            "magic" = "󱐡 ";
            "hidden" = " ";
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

        "hyprland/window" = {
          icon = true;
          rewrite = {
            ".+" = "";
          };
          # format = "{}";
          # separate-outputs = true;
          # rewrite = {
          #   "(.*) Edge" = "   Edge ";
          #   "(.*) Google Chrome" = "  Chrome ";
          #   "(.*) Slack" = "  Slack";
          #   "(.*) Mozilla Thunderbird" = "  ";
          #   "(.*) bash" = " 󰆍 Kitty ";
          #   "(.*) zsh" = " 󰆍 Kitty ";
          #   "(.*) Teams" = " 󰊻 Teams ";
          #   "Spotify (.*)" = "  Spotify ";
          #   "(.*) nvim" = "  Nvim ";
          #   "(.*) Alacritty" = "   Terminal ";
          #   "~/(.*)" = "   Terminal ";
          #   "(.*) Zellij" = "  Zellij ";
          # };
        };

        "tray" = {
          spacing = 12;
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
          format = "{:%H:%M} |";
          max-lenght = 25;
          min-length = 6;
          format-alt = "{:%A, %B %d, %Y (%R)} |";
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
          format = "{capacity}% |";
          format-charging = "{capacity}% |";
          format-plugged = "{capacity}% |";
          format-alt = "{time} |";
        };

        "battery#icons" = {
          format = "{icon}";
          format-charging = "";
          format-plugged = "";
          format-icons = [ "󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
        };

        "network#icons" = {
          format-wifi = "󰖩";
          format-ethernet = "󰈀";
          tooltip-format = "󰈀";
          format-linked = "󰈀";
          format-disconnected = "";
          format-alt = "󰖩";
        };

        "network" = {
          format-wifi = "{essid} |";
          format-ethernet = "{ipaddr} |";
          tooltip-format = "{ipaddr}  {bandwidthUpBytes}  {bandwidthDownBytes}";
          format-linked = "{ifname} (No IP)";
          format-disconnected = "Disconnected";
          format-alt = "{signalStrength}% |";
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
          format = "{status}|";
          format-connected = "{num_connections}";
          tooltip-format = "{device_alias}";
          tooltip-format-connected = "{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}";
          on-click = "wezterm start -- bash -c bluetuith --color dark";
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
          format = "{volume}% |";
          format-bluetooth = "{volume}%|";
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
          format = "{} |";
          tooltip = true;
          interval = 3600;
        };

        "custom/spotify" = {
          format = " ";
          tooltip = false;
        };

        "custom/playerctl" = {
          format = "{icon}  <span>{}</span>|";
          return-type = "json";
          max-length = 30;
          exec = "${pkgs.playerctl}/bin/playerctl -p spotify_player metadata -f '{\"text\": \"{{markup_escape(title)}} - {{markup_escape(artist)}} {{ duration(position) }}/{{ duration(mpris:length) }}\", \"tooltip\": \"{{markup_escape(title)}} - {{markup_escape(artist)}}  {{ duration(position) }}/{{ duration(mpris:length) }}\", \"alt\": \"{{status}}\", \"class\": \"{{status}}\"}' && album_art -F";
          interval = 5;
          tooltip = false;
          on-click-middle = "${pkgs.playerctl}/bin/playerctl -p spotify_player previous";
          on-click = "${pkgs.playerctl}/bin/playerctl -p spotify_player play-pause";
          on-click-right = "${pkgs.playerctl}/bin/playerctl -p spotify_player next";
          on-scroll-up = "${pkgs.playerctl}/bin/playerctl -p spotify_player volume 0.02+";
          on-scroll-down = "${pkgs.playerctl}/bin/playerctl -p spotify_player volume 0.02-";
          format-icons = {
            Paused = "";
            Playing = "";
          };
        };

        "pulseaudio#microphoneicons" = {
          format = "{format_source}";
          format-source = "";
          format-source-muted = " ";
        };

        "pulseaudio#microphone" = {
          format-source = "{volume}% |";
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
          "format" = "{} {icon} |";
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
          font-weight: bolder;
          font-style: normal;
          color: #${config.colorScheme.palette.base07};
          background-color: transparent;
          margin: 2px 2px 2px 2px;
        }
        
        #workspaces button:hover {
          font-weight: bolder;
          color: #${config.colorScheme.palette.base09};
        }

        #workspaces button.active {
          color: #${config.colorScheme.palette.base05};
          font-weight: bolder;
          transition: all 0.1s ease-in-out;
        }

        #workspaces button.urgent {
          color: #${config.colorScheme.palette.base08};
          font-weight: bolder;
          transition: all 0.1s ease-in-out;
        }

        #workspaces button.secret {
          color: #${config.colorScheme.palette.base08};
          font-style: normal;
          transition: all 0.1s ease-in-out;
        }

        #workspaces button.spotify {
          color: #${config.colorScheme.palette.base0B};
          background-color: transparent;
          font-style: normal;
          font-weight: bolder;
          transition: all 0.1s ease-in-out;
          margin: 2 2px; 
          padding: 5px;
        }

        #custom-weathericons {
          font-style: normal;
          font-weight: bolder;
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
          font-weight: bolder;
          font-style: normal;
          color: #${config.colorScheme.palette.base05};
          margin: 0 5 0 0px;
        }
        
        #custom-nix-updates {
          font-weight: bolder;
          font-style: normal;
          color: #${config.colorScheme.palette.base05};
          margin: 0 5 0 0px;
        }

       #custom-startmenu {
          font-weight: bolder;
          font-style: normal;
          color: #${config.colorScheme.palette.base05};
          margin: 2 2px; 
          padding: 5px;
        }

        #custom-monitor {
          font-weight: bolder;
          font-style: normal;
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
        #idle_inhibitor.icons {
          padding: 5px;
          border: none;
          margin: 0 0 0 2px;
          font-weight: bolder;
          font-style: normal;
          color: #${config.colorScheme.palette.base05};
        }

        #idle_inhibitor {
          padding: 5px;
          border: none;
          margin: 0 2 0 0px;
          font-weight: bolder;
          font-style: normal;
          color: #${config.colorScheme.palette.base05};
        }

        #tray {
          padding: 0 5px;
          font-weight: bolder;
          font-style: normal;
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
