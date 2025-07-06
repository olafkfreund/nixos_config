# Enhanced SwayNC Configuration with Theming and Feature Flags
{
  config,
  lib,
  pkgs,
  host ? "default",
  ...
}:
with lib;
with types;
let
  # Import host-specific variables if available
  hostVars = 
    if builtins.pathExists ../../../hosts/${host}/variables.nix
    then import ../../../hosts/${host}/variables.nix
    else {};
  
  # Check if swaync is enabled via features system
  swayncEnabled = config.features.desktop.swaync or config.desktop.swaync.enable or false;
  
  # Feature flags for SwayNC
  cfg = {
    # Core features
    core = {
      enable = swayncEnabled;
      package = pkgs.swaynotificationcenter;
      autostart = true;
    };
    
    # Notification features
    notifications = {
      timeout = 10;            # Default timeout in seconds
      timeoutLow = 5;          # Low priority timeout
      timeoutCritical = 0;     # Critical notifications (0 = no timeout)
      maxVisible = 5;          # Maximum visible notifications
      iconSize = 64;           # Notification icon size
      imageHeight = 100;       # Body image height
      imageWidth = 200;        # Body image width
      showOnLockscreen = false; # Show notifications on lockscreen
    };
    
    # Control center features
    controlCenter = {
      position = "left";       # Position: left, right, center
      margins = {
        top = 10;
        bottom = 10;
        left = 10;
        right = 10;
      };
      scale = 1;               # Scale factor
      hideOnClear = true;      # Hide when all notifications cleared
      hideOnAction = true;     # Hide when action is taken
    };
    
    # Widget configuration
    widgets = {
      dnd = true;              # Do not disturb toggle
      title = true;            # Title with clear button
      notifications = true;    # Notifications list
      mpris = true;            # Media player controls
      volume = true;           # Volume controls
      brightness = false;      # Brightness controls
      buttonsGrid = true;      # Quick action buttons
      backlight = false;       # Backlight controls
      bluetooth = false;       # Bluetooth controls
      network = false;         # Network controls
    };
    
    # MPRIS (media player) settings
    mpris = {
      albumArtSize = 110;
      hideWhenInactive = true;
      forceArtwork = true;
      preferredPlayers = [ "spotify" "mpd" "firefox" ];
    };
    
    # Quick action buttons
    actions = {
      power = true;            # Power menu
      reboot = true;           # Reboot
      lock = true;             # Lock screen
      logout = true;           # Logout
      suspend = true;          # Suspend
      volumeToggle = true;     # Volume mute toggle
      micToggle = true;        # Microphone mute toggle
      networkManager = true;   # Network manager
      bluetooth = true;        # Bluetooth manager
      screenshot = false;      # Screenshot tool
      recording = false;       # Recording tool
    };
    
    # Performance and behavior
    performance = {
      transitionTime = 200;    # Animation transition time
      layerShell = true;       # Use layer shell
      fitToScreen = true;      # Fit notifications to screen
      cssPriority = "application"; # CSS priority
    };
  };
  
  # Color scheme definitions (matching other components)
  colorSchemes = {
    gruvbox-dark = {
      bg = "#282828";
      bg-light = "#3c3836";
      bg-dark = "#1d2021";
      fg = "#ebdbb2";
      border = "#504945";
      accent = "#fabd2f";
      orange = "#fe8019";
      red = "#cc241d";
      green = "#689d6a";
      blue = "#458588";
      gray = "#928374";
      transparent = "rgba(40, 40, 40, 0.9)";
    };
  };
  
  selectedTheme = hostVars.swaync.theme or "gruvbox-dark";
  activeColors = colorSchemes.${selectedTheme} or colorSchemes.gruvbox-dark;
  
  # Generate configuration based on feature flags
  generateConfig = colors: {
    "$schema" = "${cfg.core.package}/etc/xdg/swaync/configSchema.json";
    
    # Position settings
    positionX = if cfg.controlCenter.position == "left" then "left"
              else if cfg.controlCenter.position == "right" then "right"
              else "center";
    positionY = "top";
    
    # Control center configuration
    control-center-margin-top = cfg.controlCenter.margins.top;
    control-center-margin-bottom = cfg.controlCenter.margins.bottom;
    control-center-margin-right = cfg.controlCenter.margins.right;
    control-center-margin-left = cfg.controlCenter.margins.left;
    control-center-scale = cfg.controlCenter.scale;
    
    # Notification window settings
    notification-window-scale = cfg.controlCenter.scale;
    notification-icon-size = cfg.notifications.iconSize;
    notification-body-image-height = cfg.notifications.imageHeight;
    notification-body-image-width = cfg.notifications.imageWidth;
    
    # Timeout settings
    timeout = cfg.notifications.timeout;
    timeout-low = cfg.notifications.timeoutLow;
    timeout-critical = cfg.notifications.timeoutCritical;
    
    # Window behavior
    fit-to-screen = cfg.performance.fitToScreen;
    notification-window-positionX = "left";
    notification-window-positionY = "top";
    
    # Layer shell configuration
    layer-shell = cfg.performance.layerShell;
    cssPriority = cfg.performance.cssPriority;
    transition-time = cfg.performance.transitionTime;
    hide-on-clear = cfg.controlCenter.hideOnClear;
    hide-on-action = cfg.controlCenter.hideOnAction;
    
    # Widget configuration
    widgets = 
      optional cfg.widgets.dnd "dnd" ++
      optional cfg.widgets.title "title" ++
      optional cfg.widgets.notifications "notifications" ++
      optional cfg.widgets.mpris "mpris" ++
      optional cfg.widgets.volume "volume" ++
      optional cfg.widgets.brightness "backlight" ++
      optional cfg.widgets.buttonsGrid "buttons-grid";
    
    widget-config = {
      dnd = mkIf cfg.widgets.dnd {
        text = "Do not disturb";
      };
      
      title = mkIf cfg.widgets.title {
        text = "Control Center";
        clear-all-button = true;
        button-text = " 󰆴";
      };
      
      mpris = mkIf cfg.widgets.mpris {
        contents = [
          "album-art"
          "icon"
          "title"
          "artist"
          "controls"
          "position"
        ];
        
        mouse-actions = {
          on-scroll-up = "NEXT";
          on-scroll-down = "PREV";
        };
        
        album-art-size = cfg.mpris.albumArtSize;
        image-size = cfg.mpris.albumArtSize;
        text-overflow = "ellipsis";
        hide-when-inactive = cfg.mpris.hideWhenInactive;
        force-artwork = cfg.mpris.forceArtwork;
        preferred-players = cfg.mpris.preferredPlayers;
      };
      
      volume = mkIf cfg.widgets.volume {
        label = "󰕾";
        show-per-app = true;
      };
      
      backlight = mkIf cfg.widgets.brightness {
        label = "󰃞";
        device = "intel_backlight";
      };
      
      buttons-grid = mkIf cfg.widgets.buttonsGrid {
        actions = 
          optional cfg.actions.power {
            label = "󰐥";
            command = "systemctl poweroff";
          } ++
          optional cfg.actions.reboot {
            label = "";
            command = "systemctl reboot";
          } ++
          optional cfg.actions.lock {
            label = "󰌾";
            command = "hyprlock";
          } ++
          optional cfg.actions.logout {
            label = "󰍃";
            command = "hyprctl dispatch exit";
          } ++
          optional cfg.actions.suspend {
            label = "󰤄";
            command = "systemctl suspend";
          } ++
          optional cfg.actions.volumeToggle {
            label = "󰕾";
            command = "swayosd-client --output-volume mute-toggle";
          } ++
          optional cfg.actions.micToggle {
            label = "󰍬";
            command = "swayosd-client --input-volume mute-toggle";
          } ++
          optional cfg.actions.networkManager {
            label = "󰖩";
            command = "nm-connection-editor";
          } ++
          optional cfg.actions.bluetooth {
            label = "󰂯";
            command = "blueman-manager";
          } ++
          optional cfg.actions.screenshot {
            label = "󰹑";
            command = "flameshot gui";
          } ++
          optional cfg.actions.recording {
            label = "󰻂";
            command = "obs";
          };
        
        grid-width = 3;
        grid-height = 4;
      };
    };
  };
  
  # Generate CSS theme - flat design matching waybar/rofi
  generateCSS = colors: ''
    /* Flat SwayNC Theme - matching waybar and rofi */
    * {
      font-family: "JetBrainsMono Nerd Font";
      font-weight: normal;
      transition: none;
      border: none;
      border-radius: 0px;
      outline: none;
      box-shadow: none;
    }
    
    /* Main window */
    .control-center {
      background: ${colors.bg};
      border: none;
      border-radius: 0px;
      box-shadow: none;
      margin: 0px;
      padding: 0;
    }
    
    .control-center .widget-title {
      background: ${colors.bg};
      color: ${colors.fg};
      font-size: 16px;
      font-weight: bold;
      padding: 12px;
      border-radius: 0px;
      border: none;
    }
    
    .control-center .widget-title button {
      background: ${colors.bg};
      color: ${colors.accent};
      border: none;
      border-radius: 0px;
      padding: 4px 8px;
      font-size: 14px;
      font-weight: bold;
    }
    
    .control-center .widget-title button:hover {
      background: ${colors.bg};
      color: ${colors.accent};
    }
    
    /* Do Not Disturb */
    .control-center .widget-dnd {
      background: ${colors.bg};
      color: ${colors.fg};
      padding: 12px;
      border-radius: 0px;
      border: none;
      margin: 0px;
    }
    
    .control-center .widget-dnd button {
      background: ${colors.bg};
      color: ${colors.fg};
      border: none;
      border-radius: 0px;
      padding: 8px 12px;
      font-weight: bold;
    }
    
    .control-center .widget-dnd button.enabled {
      background: ${colors.bg};
      color: ${colors.accent};
    }
    
    /* Notifications */
    .notification {
      background: ${colors.bg};
      border: none;
      border-radius: 0px;
      margin: 0px;
      padding: 0;
      box-shadow: none;
    }
    
    .notification .notification-content {
      background: ${colors.bg};
      color: ${colors.fg};
      padding: 12px;
    }
    
    .notification .notification-default-action {
      background: ${colors.bg};
      color: ${colors.fg};
    }
    
    .notification .notification-default-action:hover {
      background: ${colors.bg};
      color: ${colors.accent};
    }
    
    .notification .summary {
      color: ${colors.fg};
      font-size: 14px;
      font-weight: bold;
      margin-bottom: 4px;
    }
    
    .notification .body {
      color: ${colors.fg};
      font-size: 12px;
    }
    
    .notification .app-name {
      color: ${colors.accent};
      font-size: 11px;
      font-weight: bold;
    }
    
    /* MPRIS */
    .control-center .widget-mpris {
      background: ${colors.bg};
      border-radius: 0px;
      border: none;
      margin: 0px;
      padding: 12px;
    }
    
    .control-center .widget-mpris .album-art {
      border-radius: 0px;
      margin-right: 12px;
    }
    
    .control-center .widget-mpris .title {
      color: ${colors.fg};
      font-size: 14px;
      font-weight: bold;
    }
    
    .control-center .widget-mpris .artist {
      color: ${colors.fg};
      font-size: 12px;
    }
    
    .control-center .widget-mpris button {
      background: ${colors.bg};
      color: ${colors.fg};
      border: none;
      border-radius: 0px;
      width: 32px;
      height: 32px;
      margin: 2px;
    }
    
    .control-center .widget-mpris button:hover {
      background: ${colors.bg};
      color: ${colors.accent};
    }
    
    /* Volume */
    .control-center .widget-volume {
      background: ${colors.bg};
      border-radius: 0px;
      border: none;
      margin: 0px;
      padding: 12px;
    }
    
    .control-center .widget-volume .volume-slider {
      background: ${colors.bg};
      border-radius: 0px;
    }
    
    .control-center .widget-volume .volume-slider slider {
      background: ${colors.accent};
      border-radius: 0px;
    }
    
    /* Buttons Grid */
    .control-center .widget-buttons-grid {
      background: ${colors.bg};
      border-radius: 0px;
      border: none;
      margin: 0px;
      padding: 12px;
    }
    
    .control-center .widget-buttons-grid button {
      background: ${colors.bg};
      color: ${colors.fg};
      border: none;
      border-radius: 0px;
      width: 48px;
      height: 48px;
      margin: 4px;
      font-size: 16px;
      font-weight: bold;
    }
    
    .control-center .widget-buttons-grid button:hover {
      background: ${colors.bg};
      color: ${colors.accent};
    }
    
    /* Notification window */
    .notification-window {
      background: ${colors.bg};
      border: none;
      outline: none;
      box-shadow: none;
    }
    
    /* Remove any possible window borders */
    window {
      border: none;
      outline: none;
      box-shadow: none;
    }
    
    /* Remove borders from any containers */
    .control-center-window {
      border: none;
      outline: none;
      box-shadow: none;
    }
    
    .floating-notifications .notification {
      background: ${colors.bg};
      border: none;
      border-radius: 0px;
      box-shadow: none;
      margin: 0px;
      padding: 0;
    }
    
    .floating-notifications .notification .notification-content {
      background: ${colors.bg};
      color: ${colors.fg};
      padding: 16px;
    }
    
    .floating-notifications .notification .close-button {
      background: ${colors.bg};
      color: ${colors.accent};
      border: none;
      border-radius: 0px;
      width: 24px;
      height: 24px;
      margin: 8px;
    }
    
    .floating-notifications .notification .close-button:hover {
      background: ${colors.bg};
      color: ${colors.accent};
    }
    
    /* Action buttons in notifications */
    .notification .notification-action {
      background: ${colors.bg};
      color: ${colors.accent};
      border: none;
      border-radius: 0px;
      padding: 4px 8px;
      margin: 2px;
      font-size: 11px;
      font-weight: normal;
      cursor: pointer;
    }
    
    .notification .notification-action:hover {
      background: ${colors.bg};
      color: ${colors.accent};
      text-decoration: underline;
    }
    
    /* Action text in popup notifications */
    .notification .actions {
      background: ${colors.bg};
      padding: 4px;
    }
    
    .notification .actions button {
      background: ${colors.bg};
      color: ${colors.accent};
      border: none;
      border-radius: 0px;
      padding: 2px 6px;
      margin: 1px;
      font-size: 10px;
      font-weight: normal;
      cursor: pointer;
    }
    
    .notification .actions button:hover {
      background: ${colors.bg};
      color: ${colors.accent};
      text-decoration: underline;
    }
    
    /* Critical notifications */
    .notification.critical {
      background: ${colors.bg};
    }
    
    .notification.critical .summary {
      color: ${colors.accent};
    }
    
    /* Low priority notifications */
    .notification.low {
      opacity: 1.0;
    }
    
    /* Scrollbars */
    scrollbar {
      background: ${colors.bg};
      border-radius: 0px;
      width: 0px;
    }
    
    scrollbar slider {
      background: ${colors.bg};
      border-radius: 0px;
      min-height: 0px;
    }
    
    scrollbar slider:hover {
      background: ${colors.bg};
    }
  '';
  
in {
  # Backward compatibility options for features system
  options.desktop.swaync = {
    enable = mkOption {
      type = bool;
      default = false;
      description = "Enable SwayNC notification center";
    };
  };

  config = mkIf swayncEnabled {
    # Enhanced SwayNC configuration
    services.swaync = {
      enable = true;
      package = cfg.core.package;
    };
    
    # Configuration files
    xdg.configFile = {
      "swaync/config.json".text = builtins.toJSON (generateConfig activeColors);
      "swaync/style.css".text = generateCSS activeColors;
    };
    
    # Hyprland integration
    wayland.windowManager.hyprland.settings = mkIf cfg.core.autostart {
    exec-once = mkDefault [ "swaync" ];
    
    # Layer rules for animations
    layerrule = mkDefault [
      "animation slide left, swaync-control-center"
      "animation slide top, swaync-notification-window"
    ];
    
    # Keybindings
    bind = mkDefault [
      "SUPER, N, exec, swaync-client -t -sw"  # Toggle control center
      "SUPER SHIFT, N, exec, swaync-client -d -sw"  # Dismiss notifications
    ];
  };
  
    # Additional packages
    home.packages = with pkgs; [
      # SwayNC client for commands
      cfg.core.package
      
      # Optional dependencies
      libnotify        # For notify-send
    ] ++ optionals cfg.actions.screenshot [
      flameshot        # Screenshot tool
    ] ++ optionals cfg.actions.recording [
      obs-studio       # Recording tool
    ];
    
    # Launcher scripts for common swaync actions
    home.file = {
      # Toggle control center
      ".local/bin/swaync-toggle" = {
        text = ''
          #!/bin/sh
          swaync-client -t -sw
        '';
        executable = true;
      };
      
      # Dismiss all notifications
      ".local/bin/swaync-dismiss" = {
        text = ''
          #!/bin/sh
          swaync-client -d -sw
        '';
        executable = true;
      };
      
      # Send test notification
      ".local/bin/swaync-test" = {
        text = ''
          #!/bin/sh
          notify-send "Test Notification" "This is a test notification from SwayNC" -u normal
        '';
        executable = true;
      };
    };
    
    # Environment variables
    home.sessionVariables = {
      SWAYNC_CONFIG_DIR = "${config.xdg.configHome}/swaync";
    };
  };
}