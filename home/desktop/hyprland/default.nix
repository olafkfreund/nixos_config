# Hyprland Configuration with Feature Flags
# Provides granular control over Hyprland components and features
{ config
, lib
, pkgs
, inputs
, host ? "default"
, ...
}:
with lib; let
  # Import host-specific variables if available
  hostVars =
    if builtins.pathExists ../../../../hosts/${host}/variables.nix
    then import ../../../../hosts/${host}/variables.nix { inherit lib; }
    else { };

  # Import basic enhancement systems
  performanceProfiles = import ./performance-profiles.nix { inherit config lib pkgs; };
  themeSystem = import ./theme-system.nix { inherit config lib pkgs; };
  ruleSystem = import ./rule-generators.nix { inherit config lib pkgs; };

  # Auto-detect or use specified performance profile
  selectedProfile = hostVars.hyprland.performanceProfile or "balanced";
  activePerformanceProfile = performanceProfiles.hyprland.getProfile selectedProfile;

  # Auto-detect or use specified theme
  selectedTheme = hostVars.hyprland.theme or "gruvbox-dark";
  activeTheme = themeSystem.hyprland.getTheme selectedTheme;

  # Note: workspaceSystem and validationSystem will be defined after cfg is complete

  # Feature flags with smart defaults based on host capabilities
  cfg = {
    # Core features (always enabled)
    core = {
      enable = true;
      xwayland = true;
      systemd = true;
    };

    # Performance features (now from performance profiles)
    performance = {
      animations = activePerformanceProfile.animations.enabled;
      blur = activePerformanceProfile.graphics.blur.enabled;
      shadows = activePerformanceProfile.graphics.shadows.enabled;
      vrr = activePerformanceProfile.graphics.vrr;
      allowTearing = activePerformanceProfile.graphics.allow_tearing;
    };

    # Plugin system
    plugins = {
      expo = false; # Workspace overview (disabled due to API compatibility issues)
      hyprbars = false; # Window titlebars (disabled due to API compatibility issues)
      hyprfocus = true; # Focus indicators (needed for plugin configuration)
      stack3d = true; # 3D stack animation plugin
    };

    # Utility features
    utilities = {
      idle = true; # Idle management
      lock = true; # Screen locking
      screenshots = true; # Screenshot tools
      clipboard = true; # Clipboard management
      notifications = true; # Notification system
      wallpapers = true; # Wallpaper management
    };

    # QuickShell features (experimental - runs alongside Waybar)
    quickshell = {
      enable = false; # Will be enabled via conditional import
      bar = {
        position = "top"; # Top position to avoid conflict with Waybar
        height = 32;
        transparent = true;
        offset = 0;
      };
      widgets = {
        workspaces = true;
        clock = true;
        systemTray = true;
        battery = true;
        network = true;
        audio = true;
      };
      animations = {
        enabled = activePerformanceProfile.animations.enabled;
        duration = 200;
        curve = "ease-out";
      };
    };

    # Development features
    development = {
      enable = hostVars.features.development.enable or false;
      debugging = false; # Debug tools and logging
      profiling = false; # Performance profiling
    };

    # Gaming optimizations
    gaming = {
      enable = hostVars.features.gaming.enable or false;
      immediate = true; # Immediate mode for games
      noVsync = false; # Disable VSync for competitive gaming
    };

    # Accessibility features
    accessibility = {
      enable = false;
      highContrast = false;
      largeText = false;
      screenReader = false;
    };
  };

  # Conditional imports based on feature flags
  conditionalImports =
    [
      # Core configuration (always imported)
      ./config/env.nix
      ./config/settings.nix
      ./config/binds.nix
      ./config/monitors.nix
    ]
    ++ optional cfg.utilities.idle ./hypridle.nix
    ++ optional cfg.utilities.lock ./hyprlock.nix
    ++ optional true ./config/input.nix
    ++ optional true ./config/rules.nix
    ++ optional true ./config/autostart.nix
    ++ optional true ./config/plugins.nix  # Always include for debugging
    ++ optional true ./config/workspace.nix
    ++ optional (cfg.utilities.screenshots || cfg.utilities.clipboard) ./scripts/packages.nix;

  # Conditional packages based on feature flags
  conditionalPackages =
    # Core Hyprland utilities
    [ ]
    # Wallpaper management
    ++ optionals cfg.utilities.wallpapers [
      pkgs.swww
      pkgs.swaybg
    ]
    # Screenshot and screen recording
    ++ optionals cfg.utilities.screenshots [
      pkgs.grim
      pkgs.slurp
      pkgs.swappy
      pkgs.hyprshot
      pkgs.wf-recorder
      pkgs.wl-screenrec
    ]
    # Clipboard management
    ++ optionals cfg.utilities.clipboard [
      pkgs.cliphist
      pkgs.wl-clipboard
    ]
    # Idle and lock screen
    ++ optionals cfg.utilities.idle [
      pkgs.swayidle
      pkgs.hypridle
    ]
    ++ optionals cfg.utilities.lock [
      pkgs.swaylock
      pkgs.hyprlock
      pkgs.betterlockscreen
    ]
    # Development and debugging tools
    ++ optionals cfg.development.enable [
      pkgs.hyprkeys
      pkgs.nwg-displays
    ]
    ++ optionals cfg.development.debugging [
      pkgs.glib # For debugging D-Bus issues
    ]
    # Gaming utilities
    ++ optionals cfg.gaming.enable [
      pkgs.hyprdim # Dim inactive windows
    ]
    # General utilities (always included)
    ++ [
      pkgs.eww
      pkgs.hyprnome
      pkgs.python312Packages.requests
      pkgs.xdg-utils
      pkgs.kanshi
      pkgs.hyprcursor
      # pkgs.sherlock-launcher
    ];

  # Conditional plugins based on feature flags
  conditionalPlugins =
    [ ]
    ++ optional cfg.plugins.expo pkgs.hyprlandPlugins.hyprexpo
    ++ optional cfg.plugins.hyprbars pkgs.hyprlandPlugins.hyprbars
    ++ optional cfg.plugins.hyprfocus pkgs.hyprlandPlugins.hyprfocus
    ++ optional cfg.plugins.stack3d inputs.hyprland-stack3d.packages.${pkgs.system}.default;
in
{
  imports = conditionalImports;

  # Configuration passed to child modules
  _module.args.hyprlandFeatures = cfg;
  _module.args.hyprlandTheme = activeTheme;
  _module.args.hyprlandPerformanceProfile = activePerformanceProfile;
  _module.args.hyprlandRuleGenerators = ruleSystem.hyprland.ruleGenerators;

  home.packages = conditionalPackages;

  wayland.windowManager.hyprland = {
    enable = cfg.core.enable;
    systemd = mkIf cfg.core.systemd {
      enable = true;
      variables = [ "--all" ];
    };
    xwayland.enable = cfg.core.xwayland;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = null;
    plugins = conditionalPlugins;
  };

  # Performance monitoring when development features are enabled
  home.file = mkIf cfg.development.enable {
    ".config/hypr/debug.conf".text = ''
      # Debug configuration for Hyprland
      debug {
        enable_stdout_logs = true
        disable_logs = false
      }
    '';
  };

  # Gaming-specific environment variables
  home.sessionVariables = mkMerge [
    (mkIf cfg.gaming.enable {
      # Gaming optimizations
      __GL_SYNC_TO_VBLANK =
        if cfg.gaming.noVsync
        then "0"
        else "1";
      __GL_SYNC_DISPLAY_DEVICE = "1";
    })
    (mkIf cfg.accessibility.enable {
      # Accessibility settings
      GTK_THEME = mkIf cfg.accessibility.highContrast "HighContrast";
      QT_SCALE_FACTOR = mkIf cfg.accessibility.largeText "1.25";
    })
  ];
}
