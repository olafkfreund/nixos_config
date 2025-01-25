{config, ...}: {
  wayland.windowManager.hyprland.extraConfig = ''
    xwayland {
      force_zero_scaling = true
    }

    misc {
      animate_mouse_windowdragging=true
      mouse_move_focuses_monitor = true
      initial_workspace_tracking = 0
      mouse_move_enables_dpms = true
      key_press_enables_dpms = false
      animate_manual_resizes = true
      middle_click_paste = true
    }

    general {
        # sensitivity = 1.0
        gaps_in = 2
        gaps_out = 2
        border_size = 2
        layout = master
        resize_on_border = true
        # col.active_border = rgb(689d6a)
        col.active_border = rgb(ebdbb2)
        col.inactive_border = rgb(ebdbb2)
    }

    decoration {
      rounding = 0
      blur {
          enabled = true
          size = 12
          passes = 6
          new_optimizations = on
          ignore_opacity = off
      }
      shadow {
          enabled = false
          range = 30
          render_power = 3
          offset = 0 40
          # color = 0x66000000
          color = rgb(ebdbb2)
      }
      active_opacity = 1.0
      inactive_opacity = 1.0
      fullscreen_opacity = 1.0
    }

    animations {
        enabled=true
        bezier = linear, 0, 0, 1, 1
        bezier = md3_standard, 0.2, 0, 0, 1
        bezier = md3_decel, 0.05, 0.7, 0.1, 1
        bezier = md3_accel, 0.3, 0, 0.8, 0.15
        bezier = overshot, 0.05, 0.9, 0.1, 1.1
        bezier = crazyshot, 0.1, 1.5, 0.76, 0.92
        bezier = hyprnostretch, 0.05, 0.9, 0.1, 1.0
        bezier = fluent_decel, 0.1, 1, 0, 1
        bezier = easeInOutCirc, 0.85, 0, 0.15, 1
        bezier = easeOutCirc, 0, 0.55, 0.45, 1
        bezier = easeOutExpo, 0.16, 1, 0.3, 1
        bezier = drag, 0.2, 1, 0.2, 1
        bezier = pop, 0.1, 0.8, 0.2, 1
        bezier = liner, 1, 1, 1, 1
    }

    dwindle {
        pseudotile = true
        force_split = 2
        preserve_split = true
        # no_gaps_when_only = false
    }

    master {
        # no_gaps_when_only = false
        always_center_master = true
        smart_resizing = true
        new_status = master
        orientation = right
    }

    gestures {
        workspace_swipe=yes
        workspace_swipe_fingers=3
    }

    blurls = notifications
    blurls = swayosd
  '';
}
