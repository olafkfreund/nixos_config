{ lib
, pkgs
, config
, host ? "default"
, ...
}:
with lib; let
  # Import host-specific variables if available
  # Host-specific temperature sensor configuration
  temperatureConfig = {
    p620 = {
      # AMD Ryzen system - use k10temp
      hwmon-path = "/sys/class/hwmon/hwmon2/temp1_input";
      tooltip = "AMD CPU Temperature: {temperatureC}°C";
    };
    p510 = {
      # Intel Xeon system - use coretemp
      hwmon-path = "/sys/class/hwmon/hwmon6/temp1_input";
      tooltip = "Intel Xeon Package: {temperatureC}°C";
    };
    razer = {
      # Intel mobile system - use coretemp
      hwmon-path = "/sys/class/hwmon/hwmon6/temp1_input";
      tooltip = "Intel CPU Package: {temperatureC}°C";
    };
    dex5550 = {
      # Intel small form factor - use coretemp
      hwmon-path = null; # Let auto-detection work
      tooltip = "Intel CPU Temperature: {temperatureC}°C";
    };
    default = {
      # Fallback configuration
      hwmon-path = null;
      tooltip = "CPU Temperature: {temperatureC}°C";
    };
  };

  # Get configuration for current host
  currentTempConfig = temperatureConfig.${host} or temperatureConfig.default;
in
{
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
          "custom/ai-assistant"
          "hyprland/workspaces"
          "sway/workspaces"
          "sway/scratchpad"
          "sway/mode"
          "hyprland/submap"
          # "temperature"
        ];

        "modules-right" = [
          # "clock"
          "network"
          "cpu"
          "memory"
          "temperature"
          "pulseaudio"
          "pulseaudio#microphone"
          "bluetooth"
          # "custom/swaync"
          "power-profiles-daemon"
          # "network"
          "idle_inhibitor"
          "battery"
          # "tray"
          # "clock"
          "custom/swaync"
          # "custom/weather"
          # "custom/powermenu"
        ];

        "modules-center" = [
          "clock"
          # "sway/workspaces"
          # "sway/scratchpad"
          # "sway/mode"
        ];

        "memory" = {
          format = "<span foreground='#8ec07c'>󰟜 </span>{}% ";
          format-alt = "<span foreground='#8ec07c'>󰟜 </span> {used} GiB"; # 
          interval = 2;
          on-click-right = "hyprctl dispatch exec '[float; center; size 950 650] foot --override font_size=14 --title float_kitty btop'";
          states = {
            warning = 80;
          };
        };

        "cpu" = {
          format = "<span foreground='#689d6a'> </span> {usage}% ";
          format-alt = "<span foreground='#689d6a'> </span> {avg_frequency} GHz";
          interval = 2;
          on-click-right = "hyprctl dispatch exec '[float; center; size 950 650] foot --override font_size=14 --title float_kitty btop'";
          states = {
            warning = 95;
          };
        };

        "custom/cpu-advanced" = {
          exec = "cpu-advanced";
          format = " {} ";
          interval = 2;
          return-type = "json";
          tooltip = true;
          on-click-right = "hyprctl dispatch exec '[float; center; size 950 650] foot --override font_size=14 --title float_kitty btop'";
        };

        "custom/cycle_wall" = {
          format = " 󰡼 ";
          on-click = "waypaper";
        };

        "custom/ai-assistant" = {
          format = "<span foreground='#83a598'>󰜗</span>";
          tooltip = "AI Assistant - Left click: Claude Code | Right click: Gemini CLI";
          on-click = "google-chrome-stable --app=https://gemini.google.com";
          on-click-right = "google-chrome-stable --app=https://chatgpt.com";
        };

        "idle_inhibitor" = {
          format = " {icon} ";
          format-icons = {
            activated = "󰅶 ";
            deactivated = "󰾪 ";
          };
          start-activated = true;
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
            "1" = "<span foreground='#fe8019'>1</span>";
            "2" = "<span foreground='#fb4934'>2</span>";
            "3" = "<span foreground='#fabd2f'>3</span>";
            "4" = "<span foreground='#b8bb26'>4</span>";
            "5" = "<span foreground='#8ec07c'>5</span>";
            "6" = "<span foreground='#83a598'>6</span>";
            "7" = "<span foreground='#d3869b'>7</span>";
            "8" = "<span foreground='#d65d0e'>8</span>";
            "9" = "<span foreground='#fe8019'>9</span>";
            "10" = "<span foreground='#fe8019'>10</span>";
            "magic" = "<span foreground='#fabd2f'>󱕴 </span>";
            "chrome" = "<span foreground='#458588'> </span>";
            "firefox" = "<span foreground='#ff7f00'>󰈹 </span>";
            "special:firefox" = "<span foreground='#ff7f00'>󰈹 </span>";
            "special:chrome" = "<span foreground='#458588'> </span>";
            "special:magic" = "<span foreground='#fabd2f'>󱕴 </span>";
            "special:spotify" = "<span foreground='#518554'> </span>";
            "special:slack" = "<span foreground='#fe8019'> </span>";
            "special:discord" = "<span foreground='#8ec07c'> </span>";
            "special:mail" = "<span foreground='#83a598'> </span>";
            "special:scratchpad" = "<span foreground='#d3869b'> </span>";
            "hidden" = "<span foreground='#8ec07c'>󰐃 </span>";
            "secret" = "<span foreground='#fabd2f'>󱕴 </span>";
            "spotify" = "<span foreground='#518554'> </span>";
            "slack" = "<span foreground='#fe8019'> </span>";
            "discord" = "<span foreground='#8ec07c'> </span>";
            "mail" = "<span foreground='#83a598'> </span>";
            "scratchpad" = "<span foreground='#d3869b'> </span>";
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
          spacing = 10;
          show-passive-items = false;
        };

        "custom/tailscale" = {
          exec = "info-tailscale";
          on-click = "choose_vpn_config";
          restart-interval = 1;
        };

        clock = {
          calendar = {
            mode = "year";
            mode-mon-col = 3;
            weeks-pos = "right";
            on-scroll = 1;
            format = {
              months = "<span color='#fabd2f'><b>{}</b></span>";
              days = "<span color='#ebdbb2'><b>{}</b></span>";
              weeks = "<span color='#83a598'><b>W{}</b></span>";
              weekdays = "<span color='#8ec07c'><b>{}</b></span>";
              today = "<span color='#fb4934'><b><u>{}</u></b></span>";
            };
          };
          format = "  {:%H:%M}";
          tooltip = "true";
          tooltip-format = "<big>{:%Y}</big>\n<tt><small>{calendar}</small></tt>";
          format-alt = "  {:%d/%m}";
          on-click = "weather-popup";
          on-left-click = "foot -e 'zsh -c thunderbird -calendar'";
        };

        "battery" = {
          format = "<span foreground='#fabd2f'>{icon}</span> {capacity}%";
          format-icons = [
            " "
            " "
            " "
            " "
            " "
          ];
          format-charging = "<span foreground='#fabd2f'> </span>{capacity}%";
          format-full = "<span foreground='#fabd2f'> </span>{capacity}%";
          format-warning = "<span foreground='#fabd2f'> </span>{capacity}%";
          interval = 5;
          states = {
            warning = 20;
          };
          format-time = "{H}h{M}m";
          tooltip = true;
          tooltip-format = "{time}";
        };

        "custom/powermenu" = {
          format = " ";
          on-click = "pmenu";
          tooltip = false;
        };

        "network" = {
          format = "{ifname} {ipaddr} ";
          format-wifi = "<span foreground='#B16286'>󰖩 </span>";
          format-ethernet = "<span foreground='#B16286'>󰈀 </span>{ifname} ";
          tooltip-format-wifi = "Network Details:\n• SSID: {essid}\n• BSSID: {bssid}\n• Signal: {signalStrength}% ({signaldBm}dBm)\n• Frequency: {frequency}GHz\n• Interface: {ifname}\n• IP Address: {ipaddr}\n• Subnet: {cidr}\n• Gateway: {gwaddr}\n• Upload: {bandwidthUpBytes}\n• Download: {bandwidthDownBytes}\n• Total: {bandwidthTotalBytes}";
          tooltip-format-ethernet = "Ethernet Details:\n• Interface: {ifname}\n• IP Address: {ipaddr}\n• Subnet: {cidr}\n• Gateway: {gwaddr}\n• Upload: {bandwidthUpBytes}\n• Download: {bandwidthDownBytes}\n• Total: {bandwidthTotalBytes}";
          tooltip-format-disconnected = "Network Disconnected";
          format-linked = "{ifname} (No IP)";
          format-disconnected = "<span foreground='#fb4934'> 󰌙 </span>";
          format-alt = "{signalStrength}% ";
          interval = 1;
          on-click = "foot -e 'nmtui'";
        };

        "bluetooth" = {
          format = "<span foreground='#fabd2f'> 󰂯 </span>{status}";
          format-on = "<span foreground='#fabd2f'> 󰂯 </span>{status}";
          format-off = "";
          format-disabled = ""; # an empty format will hide the module
          format-connected = "<span foreground='#fabd2f'>  </span>{num_connections} ";
          on-click = "foot -e 'bluetuith --color dark'";
        };

        "pulseaudio" = {
          format = "<span foreground='#83a598'> {icon} </span>{volume}%";
          format-bluetooth = "<span foreground='#83a598'> {icon} </span>{volume}% ";
          format-muted = "<span foreground='#83a598'> </span> {volume}%";
          on-click = "foot -e 'wiremix'";
          tooltip-format = " {icon} {desc} // {volume}%";
          scroll-step = 1;
          format-icons = {
            car = "";
            default = [ "" " " " " ];
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

        "temperature" =
          {
            format = "<span foreground='#fe8019'> {icon}</span> {temperatureC}°C ";
            format-icons = [ "" "" "" "" "" "󰸁" ];
            # Host-aware temperature sensor configuration
            tooltip-format = currentTempConfig.tooltip;
            interval = 5;
            on-click = "${config.home.homeDirectory}/.config/nixos/scripts/temp-dashboard-simple.sh";
          }
          // optionalAttrs (currentTempConfig.hwmon-path != null) {
            hwmon-path = currentTempConfig.hwmon-path;
          };

        "power-profiles-daemon" = {
          format = " {icon} ";
          tooltip-format = "Power profile: {profile}\nDriver: {driver}";
          tooltip = true;
          format-icons = {
            default = " ";
            performance = "<span foreground='#fb4934'> </span>";
            balanced = "<span foreground='#8ec07c'> </span>";
            power-saver = "<span foreground='#689d6a'> </span>";
          };
        };

        "sway/mode" = {
          format = "{}";
          max-length = 50;
        };

        "sway/scratchpad" = {
          format = "{icon} {count}";
          show-empty = false;
          format-icons = [ "" "" ];
          tooltip = true;
          tooltip-format = "{app}: {title}";
        };

        # "wlr/workspaces" = {
        #   on-click = "activate";
        # };

        "custom/swaync" = {
          tooltip = false;
          format = "{icon} {}";
          format-icons = {
            notification = "<span foreground='#fabd2f'>󰂚</span>";
            none = "<span foreground='#ebdbb2'>󰂚</span>";
            dnd-notification = "<span foreground='#fb4934'>󰂛</span>";
            dnd-none = "<span foreground='#928374'>󰂛</span>";
            inhibited-notification = "<span foreground='#fabd2f'>󰂚</span>";
            inhibited-none = "<span foreground='#ebdbb2'>󰂚</span>";
            dnd-inhibited-notification = "<span foreground='#fb4934'>󰂛</span>";
            dnd-inhibited-none = "<span foreground='#928374'>󰂛</span>";
          };
          return-type = "json";
          exec-if = "which swaync-client";
          exec = "${pkgs.swaynotificationcenter}/bin/swaync-client -swb";
          on-click = "${pkgs.swaynotificationcenter}/bin/swaync-client -t";
          on-click-right = "${pkgs.swaynotificationcenter}/bin/swaync-client -C";
          on-click-middle = "${pkgs.swaynotificationcenter}/bin/swaync-client -d -sw";
          escape = true;
        };

        "pulseaudio#microphone" = {
          format = " {icon} {format_source} ";
          format-source = "<span foreground='#83a598'> </span>{volume}%";
          format-source-muted = "<span foreground='#83a598'> </span>";
          on-click = "${pkgs.foot}/bin/foot -e 'wiremix'";
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
        font-family: "JetBrainsMono Nerd Font";
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
          font-family: JetBrainsMono Nerd Font;
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
          border-radius: 0px;
          margin-left: 4px;
          margin-bottom: 2px;
          margin-top: 2px;
          font-family: JetBrainsMono Nerd Font;
          font-weight: bold;
          font-size: 14px;
          padding-top: 4px;
          padding-bottom: 4px;
          padding-left: 13px;
          padding-right: 13px;
          transition: transform 0.1s ease-in-out;
          color: #ebdbb2;
          background-color: transparent;
        }

        #workspaces button:hover {
          color: #fabd2f;
          background-color: transparent;
        }

        #workspaces button.active {
          color: #fabd2f;
          background-color: transparent;
          border-bottom: 2px solid #ebdbb2;
        }

        #custom-ai-assistant {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font;
          font-size: 14px;
          font-weight: bold;
          border-radius: 5px;
          margin-bottom: 2px;
          margin-right: 5px;
          padding-left: 8px;
          padding-right: 8px;
        }

        #custom-weather {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font;
          font-size: 15px;
          font-weight: bold;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #clock {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #custom-swaync {
          color:  #ebdbb2;
          font-family: JetBrainsMono Nerd Font;
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
          font-family: JetBrainsMono Nerd Font;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #pulseaudio {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #pulseaudio.microphone {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #pulseaudio.muted {
          color: #e23c2c;
          font-family: JetBrainsMono Nerd Font;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #network {
          color:  #ebdbb2;
          font-family: JetBrainsMono Nerd Font;
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
          font-family: JetBrainsMono Nerd Font;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #idle_inhibitor.activated {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #tray {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #tray {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #tray > .active {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font;
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
          font-family: JetBrainsMono Nerd Font;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #cpu {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #custom-cpu-advanced {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #custom-cpu-advanced.low {
          color: #8ec07c;
        }

        #custom-cpu-advanced.normal {
          color: #ebdbb2;
        }

        #custom-cpu-advanced.warning {
          color: #fabd2f;
        }

        #custom-cpu-advanced.critical {
          color: #fb4934;
        }

        #memory {
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }

        #custom-powermenu {
          background-color: #282828;
          color: #ebdbb2;
          font-family: JetBrainsMono Nerd Font;
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
          font-family: JetBrainsMono Nerd Font;
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
          font-family: JetBrainsMono Nerd Font;
          font-size: 14px;
          font-weight: bold;
          border: none;
          border-radius: 5px;
          margin-bottom: 2px;
        }
    '';
  };
}
