# Hyprland Keybinds Configuration
# Converted to native Nix configuration for better type safety and maintainability
{
  config,
  lib,
  ...
}:
with lib; {
  wayland.windowManager.hyprland.settings = {
    # Define the main modifier key
    "$mainMod" = "SUPER";

    # Window and workspace navigation keybinds
    bind = [
      # Window focus movement (vim-style)
      "$mainMod, h, movefocus, l"
      "$mainMod, l, movefocus, r"
      "$mainMod, k, movefocus, u"
      "$mainMod, j, movefocus, d"

      # Workspace switching (numbers 1-10)
      "$mainMod, 1, workspace, 1"
      "$mainMod, 2, workspace, 2"
      "$mainMod, 3, workspace, 3"
      "$mainMod, 4, workspace, 4"
      "$mainMod, 5, workspace, 5"
      "$mainMod, 6, workspace, 6"
      "$mainMod, 7, workspace, 7"
      "$mainMod, 8, workspace, 8"
      "$mainMod, 9, workspace, 9"
      "$mainMod, 0, workspace, 10"
      
      # Mouse wheel workspace switching
      "$mainMod, mouse_down, workspace, e-1"
      "$mainMod, mouse_up, workspace, e+1"
      
      # Relative workspace navigation
      "$mainMod CTRL, l, workspace, r+1"
      "$mainMod CTRL, h, workspace, r-1"

      # Application launchers
      "$mainMod, RETURN, exec, [float; size 50% 50%; center]foot"
      "$mainMod, space, exec, pkill rofi || rofi -show drun"
      "$mainMod, backspace, exec, rofi-hyprkeys"
      "$mainMod CTRL, Y, exec, [float]foot yai"
      "$mainMod CTRL, M, exec, monitors"
      "$mainMod, C, exec, thunderbird -calendar"
      "$mainMod, A, exec, [float;notitle;]kitty --class album-art --hold mpris-album-art"

      # Special workspace toggles
      "$mainMod, S, togglespecialworkspace, magic"
      "$mainMod, B, togglespecialworkspace, chrome"
      "$mainMod, M, togglespecialworkspace, mail"
      "$mainMod, T, togglespecialworkspace, scratchpad"
      "$mainMod, D, togglespecialworkspace, discord"
      "Control_SHIFT, M, togglespecialworkspace, spotify"
      
      # Weather popup and utility binds
      "$mainMod SHIFT, W, exec, weather-popup"
      "$mainMod, Escape, killactive, title:^(Weather - London)$"

      # Move windows to workspaces
      "$mainMod SHIFT, 1, movetoworkspace, 1"
      "$mainMod SHIFT, 2, movetoworkspace, 2"
      "$mainMod SHIFT, 3, movetoworkspace, 3"
      "$mainMod SHIFT, 4, movetoworkspace, 4"
      "$mainMod SHIFT, 5, movetoworkspace, 5"
      "$mainMod SHIFT, 6, movetoworkspace, 6"
      "$mainMod SHIFT, 7, movetoworkspace, 7"
      "$mainMod SHIFT, 8, movetoworkspace, 8"
      "$mainMod SHIFT, 9, movetoworkspace, 9"
      "$mainMod SHIFT, 0, movetoworkspace, 10"

      # Move windows within workspace
      "$mainMod SHIFT, h, movewindow, l"
      "$mainMod SHIFT, l, movewindow, r"
      "$mainMod SHIFT, k, movewindow, u"
      "$mainMod SHIFT, j, movewindow, d"
      "$mainMod SHIFT, c, centerwindow, none"

      # Window management
      "$mainMod, Q, killactive"
      "$mainMod, F, fullscreen, 1"
      "$mainMod, F, togglefloating"
      "$mainMod ALT, P, pin"
      "$mainMod, Y, exec, hyprctl keyword general:layout \"dwindle\""
      "$mainMod, U, exec, hyprctl keyword general:layout \"master\""

      # Layout management
      "$mainMod, I, layoutmsg, cyclenext"
      "$mainMod, O, layoutmsg, swapwithmaster master"
      "$mainMod SHIFT, U, layoutmsg, orientationcycle"
      "$mainMod SHIFT, I, layoutmsg, cycleprev"
      "$mainMod SHIFT, O, layoutmsg, focusmaster auto"
      "$mainMod, BRACKETLEFT, layoutmsg, rollnext"
      "$mainMod, BRACKETRIGHT, layoutmsg, rollprev"

      # Group management
      "$mainMod, G, togglegroup"
      "$mainMod SHIFT, G, moveoutofgroup"
      "ALT, left, changegroupactive, b"
      "ALT, right, changegroupactive, f"

      # System controls
      "$mainMod SHIFT, P, exec, screenshoot"
      "$mainMod SHIFT, S, exec, foot -e d"
      "$mainMod SHIFT, I, exec, open-clip"
      "$mainMod, N, exec, swaync-client --toggle-panel"
      "$mainMod SHIFT, N, exec, swaync-client --close-all"
      "$mainMod ALT, L, exec, hyprlock"

      # Volume controls
      "$mainMod, SLASH, exec, pamixer -t"
      "$mainMod SHIFT, V, exec, pamixer -d 2"
      "$mainMod SHIFT, B, exec, pamixer -i 2"
      ", XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise --max-volume 120"
      ", XF86AudioLowerVolume, exec, swayosd-client --output-volume lower --max-volume 120"
      ", XF86AudioMute, exec, swayosd-client --output-volume mute-toggle"
      ", XF86AudioMicMute, exec, swayosd-client --input-volume mute-toggle"

      # Brightness controls
      ", XF86MonBrightnessUp, exec, swayosd-client --brightness +10"
      ", XF86MonBrightnessDown, exec, swayosd-client --brightness -10"
      "$mainMod, F3, exec, brightnessctl -d *::kbd_backlight set +33%"
      "$mainMod, F2, exec, brightnessctl -d *::kbd_backlight set 33%-"

      # Capslock indicator
      ", release Caps_Lock, exec, swayosd-client --caps-lock"

      # Screenshot bindings
      ", Print, exec, flameshot gui --raw | wl-copy"
      "SHIFT, Print, exec, flameshot gui --path ~/Pictures/screenshots"
      
      # Resize mode entry
      "$mainMod, R, submap, resize"
    ];

    # Mouse bindings for window movement and resizing
    bindm = [
      "$mainMod, mouse:272, movewindow"
      "$mainMod, mouse:273, resizewindow"
    ];

    # Lid switch actions (laptop-specific)
    bindl = [
      ", switch:off:Lid Switch, exec, hyprctl keyword monitor \"eDP-1, 1920x1080, 0x0, 1\""
      ", switch:on:Lid Switch, exec, hyprctl keyword monitor \"eDP-1, disable\""
    ];

    # Repeatable binds for resize mode
    binde = [
      # Global resize bindings removed - now in submap
    ];

    # Submap definitions for resize mode
    submap = [
      # Resize mode bindings
      "resize,h,resizeactive,-30 0"
      "resize,l,resizeactive,30 0"
      "resize,k,resizeactive,0 -30" 
      "resize,j,resizeactive,0 30"
      "resize,escape,submap,reset"
      "resize,return,submap,reset"
    ];
  };
}
