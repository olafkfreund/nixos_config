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
        "position" = "top";
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
          "custom/spotify"
          # "image/albumart"
          "custom/playerctl"

        ];

        "modules-right" = [
          "custom/weathericons"
          "custom/weather"
          "network#icons"
          "network"
          "battery#icons"
          "battery"
          # "bluetooth#icons"
          # "bluetooth"
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
          # "custom/spotify"
          # "image/albumart"
          # "custom/playerctl"
        ];

        "image/albumart" = {
          exec = "album_art";
          path = "/tmp/cover.jpg";
          size = 20;
          interval = 5;
        };

        "custom/settings" = {
          format = " ";
          tooltip = false;
        };

        "custom/cycle_wall" = {
          format = " ";
          on-click = "wallpaper_picker";
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
          format = "{icon}";
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
          format = " ";
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
            "6" = [ ];
            "7" = [ ];
            "8" = [ ];
            "9" = [ ];
            "10" = [ ];
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
            "default" = "";
            "urgent" = "";
            "magic" = "";
            "hidden" = "󰐃";
            "secret" = "";
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
          format = "{:%H:%M}";
          max-lenght = 25;
          min-length = 6;
          format-alt = "{:%A, %B %d, %Y (%R)}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "month";
            mode-mon-row = 2;
            mode-mon-col = 3;
            weeks-pos = "right";
            on-scroll = 1;
            on-click-right = "mode";
            format = {
              months = "<span color='#${config.colorScheme.palette.base06}'><b>{}</b></span>";
              days = "<span color='#${config.colorScheme.palette.base06}'><b>{}</b></span>";
              weeks = "<span color='#${config.colorScheme.palette.base09}'><b>W{}</b></span>";
              weekdays = "<span color='#${config.colorScheme.palette.base05}'><b>{}</b></span>";
              today = "<span color='#${config.colorScheme.palette.base0B}'><b><u>{}</u></b></span>";
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
          format = " {capacity}% ";
          format-charging = " {capacity}% ";
          format-plugged = " {capacity}% ";
          format-alt = "{time} ";
        };

        "battery#icons" = {
          format = "{icon}";
          format-charging = " ";
          format-plugged = " ";
          format-icons = [ "󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
        };

        "network#icons" = {
          format-wifi = "󰖩 ";
          format-ethernet = "󰈀 ";
          tooltip-format = "󰈀 ";
          format-linked = "󰈀 ";
          format-disconnected = " ";
          format-alt = "󰖩 ";
        };

        "network" = {
          format-wifi = "{essid}";
          format-ethernet = "{ipaddr}";
          tooltip-format = "{ipaddr}  {bandwidthUpBytes}  {bandwidthDownBytes}";
          format-linked = "{ifname} (No IP)";
          format-disconnected = "Disconnected";
          format-alt = "{signalStrength}%";
          on-click = "nm-connection-editor";
        };

        "bluetooth#icons" = {
          format = "{icon}";
          format-on = " ";
          format-off = "󰂲 ";
          format-disabled = "󰂲 "; # an empty format will hide the module
          format-connected = " {num_connections}";
        };

        "bluetooth" = {
          format = "{status}";
          format-connected = "{num_connections}";
          tooltip-format = "{device_alias}";
          tooltip-format-connected = "{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}";
          on-click = "kitty -e bluetuith --color dark";
        };
        "pulseaudio#icons" = {
          format = "{icon}";
          format-bluetooth = "{icon} ";
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
          format-bluetooth = "{volume}% ";
          format-muted = "婢";
          format-icons = {
            car = "";
            default = [ "" " " " " ];
            headphones = "";
            headset = "";
          };
        };

        "custom/weathericons" = {
          format = " ";
          tooltip = false;
        };
        "custom/weather" = {
          exec = "weather London";
          return-type = "json";
          format = "{}";
          tooltip = true;
          interval = 3600;
        };

        "custom/spotify" = {
          format = " ";
          tooltip = false;
        };

        "custom/playerctl" = {
          format = "{icon}  <span>{}</span>";
          return-type = "json";
          max-length = 30;
          exec = "${pkgs.playerctl}/bin/playerctl -p spotify metadata -f '{\"text\": \"{{markup_escape(title)}} - {{markup_escape(artist)}} {{ duration(position) }}/{{ duration(mpris:length) }}\", \"tooltip\": \"{{markup_escape(title)}} - {{markup_escape(artist)}}  {{ duration(position) }}/{{ duration(mpris:length) }}\", \"alt\": \"{{status}}\", \"class\": \"{{status}}\"}' -F";
          tooltip = false;
          on-click-middle = "${pkgs.playerctl}/bin/playerctl -p spotify previous";
          on-click = "${pkgs.playerctl}/bin/playerctl -p spotify play-pause";
          on-click-right = "${pkgs.playerctl}/bin/playerctl -p spotify next";
          on-scroll-up = "${pkgs.playerctl}/bin/playerctl -p spotify volume 0.02+";
          on-scroll-down = "${pkgs.playerctl}/bin/playerctl -p spotify volume 0.02-";
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
          format-source = "{volume}%";
          on-click = "pavucontrol -t 4";
          tooltip-format = "{format_source} {source_desc} // {source_volume}%";
          scroll-step = 5;
        };

        "custom/cal" = {
          format = " ";
          tooltip = false;
        };
      };
    };

    style = ''
      * {
        font-family: 'Jetbrains Mono Nerd Font';
        font-size: 15px;
        }

        window#waybar {
          background-color: transparent;
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
          background: #${config.colorScheme.palette.base01};
        }

        tooltip label {
          color: #${config.colorScheme.palette.base06};
          background-color: #${config.colorScheme.palette.base01};
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
          background-color: #${config.colorScheme.palette.base01};
          border-radius: 5px;
          border-color: #${config.colorScheme.palette.base00};
          margin: 2px 2px 2px 2px;
        }
        
        #workspaces button:hover {
          box-shadow: inherit;
          font-weight: bolder;
          text-shadow: inherit;
          background-color: #${config.colorScheme.palette.base0D};
        }

        #workspaces button.active {
          color: #${config.colorScheme.palette.base06};
          background-color: #${config.colorScheme.palette.base09};
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
          background-color: #${config.colorScheme.palette.base06};
          font-style: normal;
          font-weight: bolder;
          transition: all 0.1s ease-in-out;
          border-color: #${config.colorScheme.palette.base00};
          border-radius: 5px;
          margin: 2 2px; 
          padding: 5px;
        }

        #custom-weathericons {
          font-style: normal;
          font-weight: bolder;
          margin: 0 0 0 2px;
          padding: 5px;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base0A};
          border-radius: 10px 0px 0px 10px;
          border-left: 1px solid #${config.colorScheme.palette.base00};
          border-top: 1px solid #${config.colorScheme.palette.base00};
          border-bottom: 1px solid #${config.colorScheme.palette.base00};
        }

        #custom-weather {
          margin: 0 2 0 0px;
          padding: 5px;
          color: #${config.colorScheme.palette.base07};
          background-color: #${config.colorScheme.palette.base01};
          border-radius: 0px 10px 10px 0px;
          border-top: 1px solid #${config.colorScheme.palette.base00};
          border-bottom: 1px solid #${config.colorScheme.palette.base00};
          border-right: 1px solid #${config.colorScheme.palette.base00};
        }
        
        #custom-cal {
          margin: 0 0 0 5px; 
          padding: 5px;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base0B};
          border-radius: 10px 0px 0px 10px;
          border-left: 1px solid #${config.colorScheme.palette.base00};
          border-top: 1px solid #${config.colorScheme.palette.base00};
          border-bottom: 1px solid #${config.colorScheme.palette.base00};
        }

        #clock {
          font-weight: bolder;
          font-style: normal;
          color: #${config.colorScheme.palette.base07};
          background-color: #${config.colorScheme.palette.base01};
          margin: 0 5 0 0px;
          border-radius: 0px 10px 10px 0px;
          border-right: 1px solid #${config.colorScheme.palette.base00};
          border-top: 1px solid #${config.colorScheme.palette.base00};
          border-bottom: 1px solid #${config.colorScheme.palette.base00};
        }

       #custom-startmenu {
          font-weight: bolder;
          font-style: normal;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base0D};
          border-color: #${config.colorScheme.palette.base00};
          border-radius: 5px;
          margin: 2 2px; 
          padding: 5px;
        }

        #custom-monitor {
          font-weight: bolder;
          font-style: normal;
          padding: 0 5px;
          color: #${config.colorScheme.palette.base07};
          background-color: #${config.colorScheme.palette.base01};
          border-top: 5px solid #${config.colorScheme.palette.base00};
          border-bottom: 5px solid #${config.colorScheme.palette.base00};
          border-radius: 5px;
        }

        #pulseaudio.icons {
          border: none;
          padding: 5px;
          margin: 0 0 0 0px;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base0C};
          border-radius: 10px 0px 0px 10px;
          border-left: 1px solid #${config.colorScheme.palette.base00};
          border-top: 1px solid #${config.colorScheme.palette.base00};
          border-bottom: 1px solid #${config.colorScheme.palette.base00};
        }

        #pulseaudio {
          border: none;
          padding: 5px;
          margin: 0 0 0 0px;
          color: #${config.colorScheme.palette.base07};
          background-color: #${config.colorScheme.palette.base01};
          border-radius: 0px 10px 10px 0px;
          border-right: 1px solid #${config.colorScheme.palette.base00};
          border-top: 1px solid #${config.colorScheme.palette.base00};
          border-bottom: 1px solid #${config.colorScheme.palette.base00};
        }

        #pulseaudio.microphoneicons {
          padding: 5px;
          border: none;
          margin: 0 0 0 5px;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base0A};
          border-radius: 10px 0px 0px 10px;
          border-left: 1px solid #${config.colorScheme.palette.base00};
          border-top: 1px solid #${config.colorScheme.palette.base00};
          border-bottom: 1px solid #${config.colorScheme.palette.base00};
        }

        #pulseaudio.microphone {
          padding: 5px;
          border: none;
          margin: 0 2 0 0px;
          color: #${config.colorScheme.palette.base07};
          background-color: #${config.colorScheme.palette.base01};
          border-radius: 0px 10px 10px 0px;
          border-right: 1px solid #${config.colorScheme.palette.base00};
          border-top: 1px solid #${config.colorScheme.palette.base00};
          border-bottom: 1px solid #${config.colorScheme.palette.base00};
        }

        #pulseaudio.muted {
          padding: 5px;
          border: none;
          margin: 0 2 0 0px;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base06};
          border-radius: 0px 10px 10px 0px;
        }

        #network.icons  {
          margin: 0 0 0 2px;
          border: none;
          padding: 5px;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base0E};
          border-radius: 10px 0px 0px 10px;
        }

        #network {
          margin: 0 2 0 0px;
          border: none;
          padding: 5px;
          color: #${config.colorScheme.palette.base05};
          background-color: #${config.colorScheme.palette.base01};
          border-radius: 0px 10px 10px 0px;
          border-right: 1px solid #${config.colorScheme.palette.base00};
          border-top: 1px solid #${config.colorScheme.palette.base00};
          border-bottom: 1px solid #${config.colorScheme.palette.base00};
        }

        #custom-cycle_wall {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base05};
          background-color: #${config.colorScheme.palette.base01};
          border-top: 1px solid #${config.colorScheme.palette.base00};
          border-bottom: 1px solid #${config.colorScheme.palette.base00};
        }

        #custom-tailscale {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base05};
          background-color: #${config.colorScheme.palette.base01};
          border-top: 1px solid #${config.colorScheme.palette.base00};
          border-bottom: 1px solid #${config.colorScheme.palette.base00};
          border-right: 1px solid #${config.colorScheme.palette.base00};
        }

        #custom-dunst {
          padding: 0 5px;
          color: #${config.colorScheme.palette.base05};
          background-color: #${config.colorScheme.palette.base01};
          border-top: 1px solid #${config.colorScheme.palette.base00};
          border-bottom: 1px solid #${config.colorScheme.palette.base00};
        }

        #custom-settings {
          padding: 0 5px;
          margin: 0 5 0 5px;
          color: #${config.colorScheme.palette.base05};
          background-color: #${config.colorScheme.palette.base01};
          border-radius: 10px;
          border-left: 1px solid #${config.colorScheme.palette.base00};
          border-top: 1px solid #${config.colorScheme.palette.base00};
          border-bottom: 1px solid #${config.colorScheme.palette.base00};
          border-right: 1px solid #${config.colorScheme.palette.base00};
        }
        #idle_inhibitor.icons {
          padding: 5px;
          border: none;
          margin: 0 0 0 2px;
          font-weight: bolder;
          font-style: normal;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base08};
          border-radius: 10px 0px 0px 10px;
        }

        #idle_inhibitor {
          padding: 5px;
          border: none;
          margin: 0 2 0 0px;
          font-weight: bolder;
          font-style: normal;
          color: #${config.colorScheme.palette.base05};
          background-color: #${config.colorScheme.palette.base01};
          border-radius: 0px 10px 10px 0px;
          border-right: 1px solid #${config.colorScheme.palette.base00};
          border-top: 1px solid #${config.colorScheme.palette.base00};
          border-bottom: 1px solid #${config.colorScheme.palette.base00};
        }

        #tray {
          padding: 0 5px;
          font-weight: bolder;
          font-style: normal;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base0D};
          border-radius: 10px;
          border-left: 1px solid #${config.colorScheme.palette.base00};
          border-top: 1px solid #${config.colorScheme.palette.base00};
          border-bottom: 1px solid #${config.colorScheme.palette.base00};
          border-right: 1px solid #${config.colorScheme.palette.base00};
        }

        #battery.icons {
          padding: 0 10px;
          border: none;
          margin: 0 0 0 2px;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base0F};
          border-radius: 10px 0px 0px 10px;
        }
        #battery {
          padding: 0 10px;
          border: none;
          margin: 0 2 0 0px;
          color: #${config.colorScheme.palette.base05};
          background-color: #${config.colorScheme.palette.base01};
          border-radius: 0px 10px 10px 0px;
          border-right: 1px solid #${config.colorScheme.palette.base00};
          border-top: 1px solid #${config.colorScheme.palette.base00};
          border-bottom: 1px solid #${config.colorScheme.palette.base00};
        }

        #window {
          color: #${config.colorScheme.palette.base05};
          background-color: #${config.colorScheme.palette.base01};
          border-radius: 10px;
          border-color: #${config.colorScheme.palette.base05};
          transition: all 0.1s ease-in-out;
          margin: 0 2 0 2px;
          padding: 0 10px;
          border-left: 1px solid #${config.colorScheme.palette.base00};
          border-top: 1px solid #${config.colorScheme.palette.base00};
          border-bottom: 1px solid #${config.colorScheme.palette.base00};
          border-right: 1px solid #${config.colorScheme.palette.base00};
        }

        #image {
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base06};
          border-top: 1px solid #${config.colorScheme.palette.base00};
          border-bottom: 1px solid #${config.colorScheme.palette.base00};
          border-radius: 0px 0px 0px 0px;
          margin: 0 0 0 2px;
          padding: 5px;
        }

        #custom-spotify {
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base0B};
          border-radius: 10px 0px 0px 10px;
          margin: 0 0 0 2px;
          padding: 5px;
        }
        #custom-playerctl {
          color: #${config.colorScheme.palette.base05};
          background-color: #${config.colorScheme.palette.base01};
          border-radius: 0px 10px 10px 0px;
          transition: all 0.1s ease-in-out;
          margin: 0 2 0 0px;
          padding: 5px;
          border-top: 1px solid #${config.colorScheme.palette.base00};
          border-bottom: 1px solid #${config.colorScheme.palette.base00};
          border-right: 1px solid #${config.colorScheme.palette.base00};

        }

        #bluetooth.icons {
          padding: 5px;
          border: none;
          margin: 0 0 0 2px;
          color: #${config.colorScheme.palette.base00};
          background-color: #${config.colorScheme.palette.base0D};
          border-radius: 10px 0px 0px 10px;
        }
        #bluetooth {
          padding: 5px;
          border: none;
          margin: 0 2 0 0px;
          color: #${config.colorScheme.palette.base05};
          background-color: #${config.colorScheme.palette.base01};
          border-radius: 0px 10px 10px 0px;
          border-right: 1px solid #${config.colorScheme.palette.base00};
          border-top: 1px solid #${config.colorScheme.palette.base00};
          border-bottom: 1px solid #${config.colorScheme.palette.base00};
        }
    '';
  };
}
