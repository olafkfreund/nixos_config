{...}: {
  wayland.windowManager.hyprland.extraConfig = ''
    plugin {
      hyprbars {
        bar_height = 20
        bar_color = rgb(282828)
        bar_title_enabled = true
        bar_text_align = left
        col.text = rgb(ebdbb2)
        bar_part_of_window = true
        bar_text_font = "Jetbrains Mono";
        hyprbars-button = [
          "rgb(282828), 25, , hyprctl dispatch killactive, rgb(ebdbb2)"
          "rgb(282828), 25, , hyprctl dispatch fullscreen, rgb(ebdbb2)"
          "rgb(282828), 25, 󰕔, hyprctl dispatch togglefloating, rgb(ebdbb2)"
        ];
      }
      hyprexpo {
        columns = 3
        gap_size = 5
        bg_col = rgb(111111)
        workspace_method = center current # [center/first] [workspace] e.g. first 1 or center m+1
        enable_gesture = true # laptop touchpad, 4 fingers
        gesture_distance = 300 # how far is the "max"
        gesture_positive = true # positive = swipe down. Negative = swipe up.
      }
      hyprfocus {
        enabled = yes
        animate_floating = yes
        animate_workspacechange = yes
        focus_animation = shrink
        # Beziers for focus animations
        bezier = bezIn, 0.5,0.0,1.0,0.5
        bezier = bezOut, 0.0,0.5,0.5,1.0
        bezier = overshot, 0.05, 0.9, 0.1, 1.05
        bezier = smoothOut, 0.36, 0, 0.66, -0.56
        bezier = smoothIn, 0.25, 1, 0.5, 1
        bezier = realsmooth, 0.28,0.29,.69,1.08
        # Flash settings
        flash {
            flash_opacity = 0.95
            in_bezier = realsmooth
            in_speed = 0.5
            out_bezier = realsmooth
            out_speed = 3
        }
        # Shrink settings
        shrink {
            shrink_percentage = 0.9975
            in_bezier = realsmooth
            in_speed = 1
            out_bezier = realsmooth
            out_speed = 1
        }
      }
    }
  '';
}
