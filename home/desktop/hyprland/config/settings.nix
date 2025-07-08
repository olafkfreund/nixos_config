# Hyprland Core Settings Configuration
# Converted to native Nix configuration for better type safety and maintainability
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
    if builtins.pathExists ../../../../hosts/${host}/variables.nix
    then import ../../../../hosts/${host}/variables.nix
    else {};
  
  # Hardware detection and profile configuration
  hardware = {
    gpu = hostVars.gpu or "intel";
    profile = hostVars.performanceProfile or "balanced";
    multiMonitor = hostVars.multiMonitor or false;
    screenWidth = hostVars.screenWidth or 1920;
    screenHeight = hostVars.screenHeight or 1080;
    refreshRate = hostVars.refreshRate or 60;
    hasTouchpad = hostVars.hasTouchpad or false;
  };
  
  # Feature flags with hardware-aware defaults
  cfg = {
    performance = {
      blur = hardware.profile != "battery";
      shadows = hardware.profile == "performance";
      animations = hardware.profile != "battery";
      vrr = hardware.refreshRate > 60;
      tearing = hardware.profile == "gaming";
    };
    
    # Gaming mode configuration
    gaming = {
      enable = true;
      optimizeForPerformance = hardware.gpu == "nvidia" || hardware.gpu == "amd";
      disableCompositing = true;
      enableTearing = hardware.gpu == "nvidia";
    };
    
    # Accessibility features
    accessibility = {
      enableHighContrast = false;
      reduceMotion = false;
      largerText = false;
    };
    
    # Development workflow optimizations
    development = {
      optimizeForCoding = true;
      multiWorkspace = true;
      fastSwitching = true;
    };
  };
  
  # Theme configuration with hardware-aware defaults
  theme = {
    cursor = {
      theme = "Bibata-Modern-Ice";
      size = if hardware.screenWidth > 1920 then 32 else 24;
      hideTimeout = 3;
    };
    
    colors = {
      active_border = "rgb(ebdbb2)";
      inactive_border = "rgb(504945)";
      active_opacity = 1.0;
      inactive_opacity = if hardware.profile == "battery" then 0.9 else 1.0;
      shadow_color = "rgb(1d2021)";
    };
  };
  
  # Hardware-specific performance profiles
  hardwareProfiles = {
    amd = {
      blur = { size = 16; passes = 4; new_optimizations = true; };
      render_optimization = "performance";
      max_fps = if hardware.refreshRate > 60 then hardware.refreshRate else 60;
    };
    
    nvidia = {
      blur = { size = 20; passes = 6; new_optimizations = true; };
      render_optimization = "quality";
      max_fps = if hardware.refreshRate > 60 then hardware.refreshRate else 144;
      gsync_compatible = true;
    };
    
    intel = {
      blur = { size = 8; passes = 2; new_optimizations = true; };
      render_optimization = "efficiency";
      max_fps = 60;
    };
  };
  
  # Performance-aware settings with hardware optimization
  performanceSettings = {
    # Hardware-optimized blur settings
    blur = {
      enabled = cfg.performance.blur;
      size = if cfg.performance.blur then hardwareProfiles.${hardware.gpu}.blur.size else 0;
      passes = if cfg.performance.blur then hardwareProfiles.${hardware.gpu}.blur.passes else 1;
      new_optimizations = hardwareProfiles.${hardware.gpu}.blur.new_optimizations;
      ignore_opacity = false;
      xray = false;
      # Advanced blur settings
      noise = 0.0117;
      contrast = 0.8916;
      brightness = 0.8172;
      vibrancy = 0.1696;
      vibrancy_darkness = 0.0;
    };
    
    # Hardware-optimized shadow settings
    shadow = {
      enabled = cfg.performance.shadows;
      range = if cfg.performance.shadows then (if hardware.gpu == "intel" then 20 else 30) else 0;
      render_power = if cfg.performance.shadows then (if hardware.gpu == "intel" then 2 else 3) else 1;
      offset = "0 40";
      color = mkDefault theme.colors.shadow_color;
      # Shadow quality based on hardware
      sharp = hardware.gpu == "nvidia";
    };
    
    # Hardware-optimized animation settings
    animations = {
      enabled = cfg.performance.animations;
      
      # Bezier curves optimized for different hardware
      bezier = optionals cfg.performance.animations [
        "linear, 0, 0, 1, 1"
        "md3_standard, 0.05, 0, 0, 1"
        "md3_decel, 0.03, 0.3, 0.05, 0.8"
        "md3_accel, 0.1, 0, 0.4, 0.2"
        "overshot, 0.03, 0.5, 0.1, 1.03"
        "hyprnostretch, 0.03, 0.5, 0.1, 1.0"
        "snap, 0, 0.85, 0.15, 1.0"
        "weather, 0.25, 0.1, 0.25, 1"
        "gaming, 0, 0, 1, 1"  # Linear for gaming performance
      ];
      
      # Animation assignments with hardware-specific tuning
      animation = if cfg.performance.animations then 
        let
          speed = if hardware.gpu == "intel" then 1.5 else 1.0;  # Faster animations on integrated graphics
          gaming_speed = 0.5;  # Ultra-fast for gaming mode
        in [
          "windows, 1, ${toString (25 * speed)}, md3_decel, slide"
          "border, 1, ${toString (30 * speed)}, default"
          "fade, 1, ${toString (8 * speed)}, default"
          "workspaces, 1, ${toString (20 * speed)}, md3_decel"
          "windowsOut, 1, ${toString (5 * speed)}, snap, slide"
          "specialWorkspace, 1, ${toString (6 * speed)}, weather, slidevert"
          # Gaming-specific animations
          "layers, 1, ${toString (3 * gaming_speed)}, gaming"
        ] else [
          "windows, 0"
          "border, 0"
          "fade, 0"
          "workspaces, 0"
          "layers, 0"
        ];
    };
  };
in {
  wayland.windowManager.hyprland.settings = {
    # XWayland configuration with hardware optimization
    xwayland = {
      force_zero_scaling = true;
      use_nearest_neighbor = hardware.gpu == "intel";  # Better for integrated graphics
    };

    # Cursor configuration
    cursor = {
      default_monitor = if hardware.multiMonitor then "DP-1" else "";
      theme = theme.cursor.theme;
      size = theme.cursor.size;
      no_hardware_cursors = hardware.gpu == "nvidia";  # NVIDIA driver compatibility
      hide_on_key_press = true;
      hide_on_touch = true;
      allow_dumb_copy = false;
      sync_gsettings_theme = true;
    };

    # Enhanced mouse and input behavior
    misc = {
      animate_mouse_windowdragging = cfg.performance.animations;
      mouse_move_focuses_monitor = hardware.multiMonitor;
      initial_workspace_tracking = 0;
      mouse_move_enables_dpms = true;
      key_press_enables_dpms = false;
      animate_manual_resizes = cfg.performance.animations;
      middle_click_paste = true;
      disable_hyprland_logo = true;
      disable_splash_rendering = true;
      
      # Hardware-specific VRR and performance settings
      vrr = if cfg.performance.vrr then 2 else 0;  # Full VRR when supported
      vfr = cfg.performance.vrr;  # Variable frame rate
      focus_on_activate = true;
      
      # Performance and rendering optimizations
      render_ahead_of_time = hardware.gpu != "intel";  # Disable for integrated graphics
      render_ahead_safezone = if hardware.gpu == "nvidia" then 2 else 1;
      
      # Gaming and performance features
      allow_session_lock_restore = true;
      background_color = mkDefault "rgb(1d2021)";
      splash_font_family = "JetBrainsMono Nerd Font";
      
      # Development workflow optimizations
      new_window_takes_over_fullscreen = if cfg.development.optimizeForCoding then 1 else 0;
      suppress_portal_warnings = true;
      
      # Accessibility features
      enable_swallow = !cfg.accessibility.reduceMotion;
      swallow_regex = "^(Alacritty|kitty|foot|wezterm)$";
      
      # Hardware-specific optimizations
      close_special_on_empty = true;
      layers_hog_keyboard_focus = hardware.gpu == "nvidia";
    };

    # General window appearance with hardware optimization
    general = {
      gaps_in = if hardware.profile == "battery" then 1 else 2;
      gaps_out = if hardware.profile == "battery" then 1 else 2;
      border_size = if cfg.accessibility.largerText then 3 else 2;
      layout = if cfg.development.optimizeForCoding then "master" else "dwindle";
      resize_on_border = true;
      extend_border_grab_area = 15;
      hover_icon_on_border = true;
      
      # Hardware-aware border colors
      "col.active_border" = mkDefault theme.colors.active_border;
      "col.inactive_border" = mkDefault theme.colors.inactive_border;
      
      # Hardware-specific tearing settings
      allow_tearing = cfg.performance.tearing;
      no_border_on_floating = false;
      
      # Multi-monitor specific settings
      resize_corner = if hardware.multiMonitor then 0 else 3;
      
      # Development workflow optimizations
      snap = {
        enabled = cfg.development.optimizeForCoding;
        window_gap = 8;
        monitor_gap = 8;
      };
    };

    # Group window configuration
    group = {
      "col.border_active" = mkDefault theme.colors.active_border;
      "col.border_inactive" = mkDefault theme.colors.inactive_border;
      "col.border_locked_active" = mkDefault "rgb(fe8019)";
      "col.border_locked_inactive" = mkDefault "rgb(d65d0e)";
      
      groupbar = {
        enabled = true;
        font_family = "JetBrainsMono Nerd Font";
        font_size = if cfg.accessibility.largerText then 12 else 10;
        gradients = cfg.performance.animations;
        height = if cfg.accessibility.largerText then 24 else 20;
        priority = 3;
        render_titles = true;
        scrolling = true;
        text_color = mkDefault "rgb(ebdbb2)";
        
        "col.active" = mkDefault "rgb(83a598)";
        "col.inactive" = mkDefault "rgb(504945)";
        "col.locked_active" = mkDefault "rgb(fe8019)";
        "col.locked_inactive" = mkDefault "rgb(d65d0e)";
      };
    };

    # Window decoration settings with hardware optimization
    decoration = {
      rounding = if cfg.accessibility.reduceMotion then 0 else 6;

      # Performance-aware blur configuration
      blur = performanceSettings.blur;

      # Performance-aware shadow configuration
      shadow = performanceSettings.shadow;

      # Theme-aware opacity settings with hardware optimization
      active_opacity = mkDefault theme.colors.active_opacity;
      inactive_opacity = mkDefault theme.colors.inactive_opacity;
      fullscreen_opacity = mkDefault 1.0;
      
      # Advanced decoration features
      dim_inactive = hardware.profile != "battery";
      dim_strength = if hardware.profile == "battery" then 0.1 else 0.05;
      dim_special = 0.2;
      dim_around = 0.4;
      
      # Screen tearing prevention
      screen_shader = "";
      
      # Hardware-specific decoration optimization
      drop_shadow = performanceSettings.shadow.enabled;
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

    # Enhanced input device settings
    input = {
      follow_mouse = if cfg.development.optimizeForCoding then 2 else 1;
      mouse_refocus = true;
      sensitivity = 0.0;
      accel_profile = "flat";
      force_no_accel = true;
      left_handed = false;
      scroll_method = "2fg";
      scroll_button = 0;
      natural_scroll = false;
      numlock_by_default = true;
      resolve_binds_by_sym = false;
      
      # Touchpad settings (if present)
      touchpad = optionalAttrs hardware.hasTouchpad {
        natural_scroll = true;
        disable_while_typing = true;
        gesture = true;
        drag_lock = false;
        scroll_factor = 1.0;
        middle_button_emulation = false;
        tap_button_map = "lrm";
        clickfinger_behavior = false;
        tap = true;
        tap_and_drag = true;
      };
      
      # Tablet settings
      tablet = {
        transform = 0;
        output = "";
        region_position = "0 0";
        region_size = "0 0";
      };
      
      # Keyboard settings
      kb_model = "";
      kb_layout = "us";
      kb_variant = "";
      kb_options = "caps:escape";  # Caps lock as escape for development
      kb_rules = "";
      kb_file = "";
      repeat_rate = 30;
      repeat_delay = 300;
    };
    
    # Multi-monitor configuration
    monitor = if hardware.multiMonitor then [
      # Primary monitor (adjust based on your setup)
      "DP-1,${toString hardware.screenWidth}x${toString hardware.screenHeight}@${toString hardware.refreshRate},0x0,1"
      # Secondary monitor example
      "DP-2,1920x1080@60,${toString hardware.screenWidth}x0,1"
      # Fallback for unknown monitors
      ",preferred,auto,1"
    ] else [
      # Single monitor configuration
      ",${toString hardware.screenWidth}x${toString hardware.screenHeight}@${toString hardware.refreshRate},0x0,1"
    ];

    # Workspace configuration
    workspace = lib.optionals cfg.development.multiWorkspace [
      # Development workspaces
      "1, monitor:${if hardware.multiMonitor then "DP-1" else ""}"
      "2, monitor:${if hardware.multiMonitor then "DP-1" else ""}"
      "3, monitor:${if hardware.multiMonitor then "DP-1" else ""}"
      
      # Communication workspaces
      "8, monitor:${if hardware.multiMonitor then "DP-2" else ""}"
      "9, monitor:${if hardware.multiMonitor then "DP-2" else ""}"
      "10, monitor:${if hardware.multiMonitor then "DP-2" else ""}"
      
      # Special workspaces
      "special:magic, on-created-empty:1password"
      "special:chrome, on-created-empty:google-chrome-stable"
      "special:discord, on-created-empty:discord"
      "special:spotify, on-created-empty:spotify"
      "special:mail, on-created-empty:thunderbird"
    ];
    
    # Enhanced blur areas with hardware optimization
    blurls = [
      "notifications"
      "swayosd"
      "waybar"
      "rofi"
      "wofi"
      "launcher"
      "lockscreen"
    ] ++ lib.optionals (hardware.gpu != "intel") [
      # More intensive blur areas only on discrete GPUs
      "gtk-layer-shell"
      "screenshot"
      "selection"
    ];
    
    # Layer rules for better performance and appearance
    layerrule = [
      "blur, notifications"
      "blur, swayosd"
      "blur, waybar"
      "ignorezero, waybar"
      "blur, rofi"
      "ignorealpha 0.5, rofi"
      "noanim, wallpaper"
    ] ++ lib.optionals cfg.performance.animations [
      "animation slide left, rofi"
      "animation slide right, notifications"
      "animation slide up, swayosd"
    ];
    
    # Window rules for accessibility and development
    windowrule = lib.optionals cfg.accessibility.enableHighContrast [
      "bordercolor rgb(fb4934), class:^(urgent)$"
      "bordercolor rgb(fabd2f), class:^(important)$"
    ] ++ lib.optionals cfg.development.optimizeForCoding [
      "idleinhibit focus, class:^(code)$"
      "idleinhibit focus, class:^(Code)$"
    ];
    
    # Environment variables for hardware optimization
    env = [
      "XCURSOR_SIZE,${toString theme.cursor.size}"
      "XCURSOR_THEME,${theme.cursor.theme}"
      "HYPRCURSOR_SIZE,${toString theme.cursor.size}"
      "HYPRCURSOR_THEME,${theme.cursor.theme}"
    ] ++ lib.optionals (hardware.gpu == "nvidia") [
      "LIBVA_DRIVER_NAME,nvidia"
      "XDG_SESSION_TYPE,wayland"
      "GBM_BACKEND,nvidia-drm"
      "__GLX_VENDOR_LIBRARY_NAME,nvidia"
    ] ++ lib.optionals (hardware.gpu == "amd") [
      "LIBVA_DRIVER_NAME,radeonsi"
      "VDPAU_DRIVER,radeonsi"
    ] ++ lib.optionals (hardware.gpu == "intel") [
      "LIBVA_DRIVER_NAME,iHD"
      "VDPAU_DRIVER,va_gl"
    ];
  };
}
