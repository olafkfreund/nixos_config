{...}: {
  wayland.windowManager.hyprland.extraConfig = ''
    # XWayland configuration
    xwayland {
      force_zero_scaling = true
    }

    # Mouse and input behavior
    misc {
      animate_mouse_windowdragging = true
      mouse_move_focuses_monitor = true
      initial_workspace_tracking = 0
      mouse_move_enables_dpms = true
      key_press_enables_dpms = false
      animate_manual_resizes = true
      middle_click_paste = true
      disable_hyprland_logo = true       # Remove startup logo
      disable_splash_rendering = true    # Faster startup
      vrr = 1                            # Adaptive sync
      mouse_move_enables_dpms = true     # Wake on mouse movement
      focus_on_activate = true           # Focus windows that request activation
    }

    # General window appearance
    general {
      gaps_in = 2
      gaps_out = 2
      border_size = 2
      layout = master
      resize_on_border = true
      col.active_border = rgb(ebdbb2)
      col.inactive_border = rgb(ebdbb2)
      allow_tearing = false              # Prevent screen tearing
    }

    # Window decoration settings
    decoration {
      rounding = 0

      # Blur effect
      blur {
        enabled = true
        size = 12
        passes = 4                       # Reduced from 6 for better performance
        new_optimizations = true
        ignore_opacity = false           # Use 'false' instead of 'off'
        xray = false                     # Disable x-ray effect for better performance
      }

      # Shadow effect
      shadow {
        enabled = false
        range = 30
        render_power = 3
        offset = 0 40
        color = rgb(ebdbb2)
      }

      # Window opacity settings
      active_opacity = 1.0
      inactive_opacity = 1.0
      fullscreen_opacity = 1.0
    }

    # Animation configuration
    animations {
      enabled = true

      # Bezier curves for different animation types
      bezier = linear, 0, 0, 1, 1
      bezier = md3_standard, 0.2, 0, 0, 1
      bezier = md3_decel, 0.05, 0.7, 0.1, 1
      bezier = md3_accel, 0.3, 0, 0.8, 0.15
      bezier = overshot, 0.05, 0.9, 0.1, 1.1
      bezier = hyprnostretch, 0.05, 0.9, 0.1, 1.0

      # Animation assignments (slowed down)
      animation = windows, 1, 5, md3_decel, slide    # Increased from 3 to 5
      animation = border, 1, 14, default             # Increased from 10 to 14
      animation = fade, 1, 4, default                # Increased from 2 to 4
      animation = workspaces, 1, 6, md3_decel        # Increased from 4 to 6
    }

    # Dwindle layout settings
    dwindle {
      pseudotile = true
      force_split = 2
      preserve_split = true
      smart_split = false               # Improves performance
      smart_resizing = true
    }

    # Master layout settings
    master {
      always_center_master = true
      smart_resizing = true
      new_status = master
      orientation = right
    }

    # Gesture settings
    gestures {
      workspace_swipe = true
      workspace_swipe_fingers = 3
      workspace_swipe_distance = 200     # Decrease for faster swipes
      workspace_swipe_min_speed_to_force = 15
      workspace_swipe_cancel_ratio = 0.5
    }

    # Input device settings
    input {
      follow_mouse = 1                   # Focus follows mouse
      sensitivity = 0.0                  # No acceleration
      accel_profile = flat
      touchpad {
        natural_scroll = true            # Natural scrolling on touchpad
        disable_while_typing = true      # Disable touchpad while typing
      }
    }

    # Define areas to apply blur
    blurls = notifications
    blurls = swayosd
    blurls = waybar
  '';
}
