# Hyprland Core Settings Configuration
# Converted to native Nix configuration for better type safety and maintainability
{
  config,
  lib,
  hyprlandFeatures ? {},
  hyprlandTheme ? {},
  ...
}:
with lib;
let
  # Feature flags with fallback defaults
  cfg = hyprlandFeatures;
  
  # Theme configuration with fallback defaults
  theme = hyprlandTheme;
  
  # Performance-aware settings
  performanceSettings = {
    # Blur settings based on performance capabilities
    blur = {
      enabled = cfg.performance.blur or true;
      size = if cfg.performance.blur or true then 12 else 0;
      passes = if cfg.performance.blur or true then 4 else 1;
      new_optimizations = true;
      ignore_opacity = false;
      xray = false;
    };
    
    # Shadow settings based on performance capabilities
    shadow = {
      enabled = cfg.performance.shadows or false;
      range = if cfg.performance.shadows or false then 30 else 0;
      render_power = if cfg.performance.shadows or false then 3 else 1;
      offset = "0 40";
      color = theme.hyprland.decoration.shadow.color or "rgb(ebdbb2)";
    };
    
    # Animation settings based on performance capabilities
    animations = {
      enabled = cfg.performance.animations or true;
      
      # Bezier curves for different animation types
      bezier = optionals (cfg.performance.animations or true) [
        "linear, 0, 0, 1, 1"
        "md3_standard, 0.05, 0, 0, 1"
        "md3_decel, 0.03, 0.3, 0.05, 0.8"
        "md3_accel, 0.1, 0, 0.4, 0.2"
        "overshot, 0.03, 0.5, 0.1, 1.03"
        "hyprnostretch, 0.03, 0.5, 0.1, 1.0"
        "snap, 0, 0.85, 0.15, 1.0"
        "weather, 0.25, 0.1, 0.25, 1"
      ];
      
      # Animation assignments with conditional performance tuning
      animation = if (cfg.performance.animations or true) then [
        "windows, 1, 25, md3_decel, slide"
        "border, 1, 30, default"
        "fade, 1, 8, default"
        "workspaces, 1, 20, md3_decel"
        "windowsOut, 1, 5, snap, slide"
        "specialWorkspace, 1, 6, weather, slidevert"
      ] else [
        "windows, 0"
        "border, 0"
        "fade, 0"
        "workspaces, 0"
      ];
    };
  };
in {
  wayland.windowManager.hyprland.settings = {
    # XWayland configuration
    xwayland = {
      force_zero_scaling = true;
    };

    # Mouse and input behavior
    misc = {
      animate_mouse_windowdragging = true;
      mouse_move_focuses_monitor = true;
      initial_workspace_tracking = 0;
      mouse_move_enables_dpms = true;
      key_press_enables_dpms = false;
      animate_manual_resizes = true;
      middle_click_paste = true;
      disable_hyprland_logo = true;        # Remove startup logo
      disable_splash_rendering = true;     # Faster startup
      vrr = if (cfg.performance.vrr or true) then 1 else 0;  # Adaptive sync based on feature flags
      focus_on_activate = true;            # Focus windows that request activation
    };

    # General window appearance
    general = {
      gaps_in = 2;
      gaps_out = 2;
      border_size = 2;
      layout = "master";
      resize_on_border = true;
      "col.active_border" = mkDefault (theme.hyprland.general."col.active_border" or "rgb(ebdbb2)");
      "col.inactive_border" = mkDefault (theme.hyprland.general."col.inactive_border" or "rgb(ebdbb2)");
      allow_tearing = false;               # Prevent screen tearing
    };

    # Window decoration settings
    decoration = {
      rounding = 0;

      # Performance-aware blur configuration
      blur = performanceSettings.blur;

      # Performance-aware shadow configuration (using mkDefault to allow override)
      shadow = mkDefault performanceSettings.shadow;

      # Theme-aware opacity settings (using mkDefault to allow override)
      active_opacity = mkDefault (theme.hyprland.decoration.active_opacity or 1.0);
      inactive_opacity = mkDefault (theme.hyprland.decoration.inactive_opacity or 1.0);
      fullscreen_opacity = mkDefault (theme.hyprland.decoration.fullscreen_opacity or 1.0);
    };

    # Performance-aware animation configuration
    animations = performanceSettings.animations;

    # Dwindle layout settings
    dwindle = {
      pseudotile = true;
      force_split = 2;
      preserve_split = true;
      smart_split = false;               # Improves performance
      smart_resizing = true;
    };

    # Master layout settings
    master = {
      # always_center_master = true;
      smart_resizing = true;
      new_status = "master";
      orientation = "right";
    };

    # Gesture settings
    gestures = {
      workspace_swipe = true;
      workspace_swipe_fingers = 3;
      workspace_swipe_distance = 300;     # Optimized for faster swipes
      workspace_swipe_min_speed_to_force = 15;
      workspace_swipe_cancel_ratio = 0.5;
    };

    # Input device settings
    input = {
      follow_mouse = 1;                   # Focus follows mouse
      sensitivity = 0.0;                  # No acceleration
      accel_profile = "flat";
      
      touchpad = {
        natural_scroll = true;            # Natural scrolling on touchpad
        disable_while_typing = true;      # Disable touchpad while typing
      };
    };

    # Define areas to apply blur effect
    blurls = [
      "notifications"
      "swayosd"
      "waybar"
    ];
  };
}