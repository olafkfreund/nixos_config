# Enhanced Waybar Configuration with Feature Flags and Theming
{
  config,
  lib,
  pkgs,
  host ? "default",
  ...
}:
with lib;
let
  # Import host-specific variables if available
  hostVars = 
    if builtins.pathExists ../../../hosts/${host}/variables.nix
    then import ../../../hosts/${host}/variables.nix
    else {};
  
  # Import theme system
  themeSystem = import ./themes.nix { inherit config lib; };
  
  # Feature flags for Waybar components
  cfg = {
    # Core features
    core = {
      enable = true;
      position = "bottom";
      layer = "top";
    };
    
    # Module categories
    modules = {
      workspaces = true;
      system = true;           # CPU, memory, temperature
      audio = true;            # PulseAudio controls
      network = true;          # Network status
      battery = hostVars.laptop or false;  # Auto-enable for laptops
      bluetooth = true;
      notifications = true;    # SwayNC integration
      power = true;           # Power profiles
      weather = false;        # Weather widget
      updates = false;        # System updates
    };
    
    # Visual features
    visual = {
      icons = true;
      colors = true;
      animations = true;
      transparency = true;
    };
    
    # Performance features
    performance = {
      updateInterval = 2;     # Seconds
      enableTooltips = true;
      enableScrolling = true;
    };
  };
  
  # Theme configuration
  selectedTheme = hostVars.waybar.theme or "gruvbox-dark";
  activeTheme = themeSystem.waybar.getTheme selectedTheme;
  
  # Module definitions based on feature flags
  moduleDefinitions = {
    # Left modules
    left = []
      ++ optional cfg.modules.workspaces "hyprland/workspaces"
      ++ optional cfg.modules.workspaces "sway/workspaces"
      ++ optional cfg.modules.workspaces "hyprland/submap";
    
    # Center modules
    center = [
      "clock"
    ];
    
    # Right modules
    right = []
      ++ optional cfg.modules.network "network"
      ++ optional cfg.modules.system "cpu"
      ++ optional cfg.modules.system "memory"
      ++ optional cfg.modules.system "temperature"
      ++ optional cfg.modules.audio "pulseaudio"
      ++ optional cfg.modules.audio "pulseaudio#microphone"
      ++ optional cfg.modules.bluetooth "bluetooth"
      ++ optional cfg.modules.power "power-profiles-daemon"
      ++ optional cfg.modules.battery "battery"
      ++ optional cfg.modules.notifications "custom/swaync"
      ++ optional cfg.modules.weather "custom/weather"
      ++ optional cfg.modules.updates "custom/nix-updates";
  };
  
  # Generate CSS with theme colors
  generateCSS = theme: ''
    * {
      font-family: "JetBrainsMono Nerd Font";
      font-size: 14px;
      font-weight: bolder;
    }

    window#waybar {
      background-color: ${theme.colors.bg};
      color: ${theme.colors.fg};
      transition-property: background-color;
      transition-duration: .5s;
    }

    tooltip {
      background-color: ${theme.colors.bg};
      border: none;
      border-bottom: 4px solid ${theme.colors.border};
      border-left: 4px solid ${theme.colors.border};
      border-radius: 5px;
    }

    tooltip label {
      color: ${theme.colors.fg};
      font-family: JetBrainsMono Nerd Font;
      font-size: 16px;
      padding: 0px 5px 5px 5px;
    }

    #workspaces button {
      all: unset;
      border: none;
      border-bottom: 4px solid ${theme.colors.border};
      border-left: 4px solid ${theme.colors.border};
      border-top: 1px solid ${theme.colors.border};
      border-right: 1px solid ${theme.colors.border};
      border-radius: 5px;
      margin: 2px 0px 2px 4px;
      font-family: JetBrainsMono Nerd Font;
      font-weight: bold;
      font-size: 14px;
      padding: 4px 13px;
      transition: transform 0.1s ease-in-out;
      color: ${theme.colors.fg};
      background-color: ${theme.colors.bg};
    }

    #workspaces button:hover,
    #workspaces button.active {
      border-bottom: 4px solid ${theme.colors.gray};
      border-left: 4px solid ${theme.colors.gray};
      border-top: 1px solid ${theme.colors.gray};
      border-right: 1px solid ${theme.colors.gray};
    }

    .module {
      color: ${theme.colors.fg};
      font-family: JetBrainsMono Nerd Font;
      font-size: 14px;
      font-weight: bold;
      border: none;
      border-radius: 5px;
      margin-bottom: 2px;
    }

    #clock, #cpu, #memory, #temperature, #battery, #network, 
    #bluetooth, #pulseaudio, #power-profiles-daemon, #idle_inhibitor,
    #custom-swaync, #custom-weather, #custom-nix-updates {
      @extend .module;
    }

    #pulseaudio.muted {
      color: ${theme.colors.red};
    }

    #idle_inhibitor {
      color: ${theme.colors.yellow};
    }

    #idle_inhibitor.activated {
      color: ${theme.colors.fg};
    }
  '';
  
in {
  # Enhanced Waybar - disabled for now due to conflicts with existing config
  # programs.waybar = {
  #   enable = cfg.core.enable;
    package = pkgs.waybar;
    
    settings = {
      mainBar = {
        # Core configuration
        layer = cfg.core.layer;
        position = cfg.core.position;
        mod = "dock";
        margin = "2";
        spacing = 4;
        fixed-center = true;
        exclusive = true;
        reload_style_on_change = true;
        gtk-layer-shell = true;

        # Module layout
        modules-left = moduleDefinitions.left;
        modules-center = moduleDefinitions.center;
        modules-right = moduleDefinitions.right;

        # Module configurations
        "hyprland/workspaces" = mkIf cfg.modules.workspaces {
          format = "{icon}";
          show-special = true;
          on-click = "active";
          active-only = false;
          on-scroll-up = "${pkgs.hyprland}/bin/hyprctl dispatch workspace e-1";
          on-scroll-down = "${pkgs.hyprland}/bin/hyprctl dispatch workspace e+1";
          format-icons = {
            "1" = "<span foreground='${activeTheme.colors.orange}'>1</span>";
            "2" = "<span foreground='${activeTheme.colors.red}'>2</span>";
            "3" = "<span foreground='${activeTheme.colors.yellow}'>3</span>";
            "4" = "<span foreground='${activeTheme.colors.green}'>4</span>";
            "5" = "<span foreground='${activeTheme.colors.aqua}'>5</span>";
            "6" = "<span foreground='${activeTheme.colors.blue}'>6</span>";
            "7" = "<span foreground='${activeTheme.colors.purple}'>7</span>";
            "8" = "<span foreground='${activeTheme.colors.orange}'>8</span>";
            "9" = "<span foreground='${activeTheme.colors.orange}'>9</span>";
            "10" = "<span foreground='${activeTheme.colors.orange}'>10</span>";
            "magic" = "<span foreground='${activeTheme.colors.yellow}'>󱕴 </span>";
            "chrome" = "<span foreground='${activeTheme.colors.blue}'> </span>";
            "spotify" = "<span foreground='${activeTheme.colors.green}'> </span>";
            "slack" = "<span foreground='${activeTheme.colors.orange}'> </span>";
            "discord" = "<span foreground='${activeTheme.colors.aqua}'> </span>";
            "mail" = "<span foreground='${activeTheme.colors.blue}'> </span>";
          };
        };

        cpu = mkIf cfg.modules.system {
          format = "<span foreground='${activeTheme.colors.green}'> </span> {usage}%";
          format-alt = "<span foreground='${activeTheme.colors.green}'> </span> {avg_frequency} GHz";
          interval = cfg.performance.updateInterval;
          on-click-right = "hyprctl dispatch exec '[float; center; size 950 650] foot --title float_btop btop'";
        };

        memory = mkIf cfg.modules.system {
          format = "<span foreground='${activeTheme.colors.aqua}'>󰟜 </span>{}%";
          format-alt = "<span foreground='${activeTheme.colors.aqua}'>󰟜 </span> {used} GiB";
          interval = cfg.performance.updateInterval;
          on-click-right = "hyprctl dispatch exec '[float; center; size 950 650] foot --title float_btop btop'";
        };

        clock = {
          format = "  {:%H:%M}";
          format-alt = "  {:%d/%m}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          calendar.format.today = "<span color='${activeTheme.colors.green}'><b>{}</b></span>";
          on-click = mkIf cfg.modules.weather "weather-popup";
        };

        network = mkIf cfg.modules.network {
          format-wifi = "<span foreground='${activeTheme.colors.purple}'>󰖩 </span>";
          format-ethernet = "<span foreground='${activeTheme.colors.purple}'>󰈀 </span>";
          format-disconnected = "<span foreground='${activeTheme.colors.red}'> 󰌙 </span>";
          tooltip-format = "{ipaddr}  {bandwidthUpBytes}  {bandwidthDownBytes}";
          on-click = "foot -e nmtui";
        };

        battery = mkIf cfg.modules.battery {
          format = "<span foreground='${activeTheme.colors.yellow}'>{icon}</span> {capacity}%";
          format-charging = "<span foreground='${activeTheme.colors.yellow}'> </span>{capacity}%";
          format-full = "<span foreground='${activeTheme.colors.yellow}'> </span>{capacity}%";
          format-icons = [" " " " " " " " " "];
          interval = 5;
          states.warning = 20;
        };

        pulseaudio = mkIf cfg.modules.audio {
          format = "<span foreground='${activeTheme.colors.blue}'> {icon} </span>{volume}%";
          format-muted = "<span foreground='${activeTheme.colors.blue}'> </span> {volume}%";
          format-icons.default = ["" " " " "];
          on-click = "pavucontrol -t 3";
          scroll-step = 1;
        };

        bluetooth = mkIf cfg.modules.bluetooth {
          format = "<span foreground='${activeTheme.colors.yellow}'> 󰂯 </span>{status}";
          format-connected = "<span foreground='${activeTheme.colors.yellow}'>  </span>{num_connections}";
          format-off = "";
          on-click = "foot -e bluetuith";
        };

        "custom/swaync" = mkIf cfg.modules.notifications {
          tooltip = false;
          format = "{icon}";
          format-icons = {
            notification = "<span foreground='${activeTheme.colors.red}'><sup></sup></span>";
            none = "";
            dnd-notification = "<span foreground='${activeTheme.colors.red}'><sup></sup></span>";
            dnd-none = "";
          };
          return-type = "json";
          exec = "${pkgs.swaynotificationcenter}/bin/swaync-client -swb";
          on-click = "${pkgs.swaynotificationcenter}/bin/swaync-client -t";
          on-click-right = "${pkgs.swaynotificationcenter}/bin/swaync-client -C";
        };

        "power-profiles-daemon" = mkIf cfg.modules.power {
          format = " {icon} ";
          tooltip-format = "Power profile: {profile}\nDriver: {driver}";
          format-icons = {
            performance = "<span foreground='${activeTheme.colors.red}'> </span>";
            balanced = "<span foreground='${activeTheme.colors.green}'> </span>";
            power-saver = "<span foreground='${activeTheme.colors.aqua}'> </span>";
          };
        };

        temperature = mkIf cfg.modules.system {
          format = "<span foreground='${activeTheme.colors.orange}'> {icon}</span> {temperatureC}°C";
          format-icons = ["" "" "" "" "" "󰸁"];
          interval = 10;
        };
      };
    };

    style = generateCSS activeTheme;
  };
}