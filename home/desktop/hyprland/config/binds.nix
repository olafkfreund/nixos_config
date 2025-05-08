{
  config,
  pkgs,
  ...
}: {
  wayland.windowManager.hyprland.extraConfig = ''
    # System binds
    $mainMod = SUPER

    # Window/Workspace Navigation
    bind = ALT, TAB, hyprexpo:expo, toggle
    bind = $mainMod, h, movefocus, l
    bind = $mainMod, l, movefocus, r
    bind = $mainMod, k, movefocus, u
    bind = $mainMod, j, movefocus, d

    # Workspace switching
    bind = $mainMod, 1, workspace, 1
    bind = $mainMod, 2, workspace, 2
    bind = $mainMod, 3, workspace, 3
    bind = $mainMod, 4, workspace, 4
    bind = $mainMod, 5, workspace, 5
    bind = $mainMod, 6, workspace, 6
    bind = $mainMod, 7, workspace, 7
    bind = $mainMod, 8, workspace, 8
    bind = $mainMod, 9, workspace, 9
    bind = $mainMod, 0, workspace, 10
    bind = $mainMod, mouse_down, workspace, e-1
    bind = $mainMod, mouse_up, workspace, e+1
    bind = $mainMod CTRL, l, workspace, r+1
    bind = $mainMod CTRL, h, workspace, r-1

    # Application launchers
    # bind = $mainMod, E, exec, pkill rofi || rofi -modi "emoji:rofi-emoji" -show emoji
    bind = $mainMod, RETURN, exec, [float; size 50% 50%; center]foot
    bind = $mainMod, space, exec, pkill rofi || rofi -show drun
    bind = $mainMod, backspace, exec, rofi-hyprkeys
    bind = $mainMod SHIFT, S, exec, search_web
    bind = $mainMod CTRL, Y, exec, [float]foot yai
    bind = $mainMod CTRL, M, exec, monitors

    # Special workspaces
    bind = $mainMod, S, togglespecialworkspace, magic
    bind = $mainMod, M, togglespecialworkspace, mail
    bind = $mainMod, T, togglespecialworkspace, scratchpad
    bind = $mainMod CTRL, S, togglespecialworkspace, spotify
    bind = Control_SHIFT, M, togglespecialworkspace, spotify
    bind = $mainMod ALT, H, togglespecialworkspace, hidden

    # Moving windows to workspaces
    bind = $mainMod SHIFT, 1, movetoworkspace, 1
    bind = $mainMod SHIFT, 2, movetoworkspace, 2
    bind = $mainMod SHIFT, 3, movetoworkspace, 3
    bind = $mainMod SHIFT, 4, movetoworkspace, 4
    bind = $mainMod SHIFT, 5, movetoworkspace, 5
    bind = $mainMod SHIFT, 6, movetoworkspace, 6
    bind = $mainMod SHIFT, 7, movetoworkspace, 7
    bind = $mainMod SHIFT, 8, movetoworkspace, 8
    bind = $mainMod SHIFT, 9, movetoworkspace, 9
    bind = $mainMod SHIFT, 0, movetoworkspace, 10
    bind = $mainMod SHIFT, M, movetoworkspace, special:mail
    bind = $mainMod SHIFT, S, movetoworkspace, special:magic
    bind = $mainMod ALT, H, movetoworkspace, special:hidden

    # Moving windows within workspace
    bind = $mainMod SHIFT, h, movewindow, l
    bind = $mainMod SHIFT, l, movewindow, r
    bind = $mainMod SHIFT, k, movewindow, u
    bind = $mainMod SHIFT, j, movewindow, d
    bind = $mainMod SHIFT, c, centerwindow, none

    # Window management
    bind = $mainMod, W, killactive
    bind = $mainMod, F, fullscreen, 1
    bind = $mainMod, F, togglefloating
    bind = $mainMod, P, pin
    bind = $mainMod, Y, exec, hyprctl keyword general:layout "dwindle"
    bind = $mainMod, U, exec, hyprctl keyword general:layout "master"

    # Mouse bindings
    bindm = $mainMod, mouse:272, movewindow
    bindm = $mainMod, mouse:273, resizewindow

    # Layout management
    bind = $mainMod, I, layoutmsg, cyclenext
    bind = $mainMod, O, layoutmsg, swapwithmaster master
    bind = $mainMod SHIFT, U, layoutmsg, orientationcycle
    bind = $mainMod SHIFT, I, layoutmsg, cycleprev
    bind = $mainMod SHIFT, O, layoutmsg, focusmaster auto
    bind = $mainMod, BRACKETLEFT, layoutmsg, rollnext
    bind = $mainMod, BRACKETRIGHT, layoutmsg, rollprev

    # Group management
    bind = $mainMod, G, togglegroup
    bind = $mainMod SHIFT, G, moveoutofgroup
    bind = ALT, left, changegroupactive, b
    bind = ALT, right, changegroupactive, f

    # System controls
    bind = $mainMod SHIFT, P, exec, screenshoot
    bind = $mainMod SHIFT, I, exec, cliphist list | rofi -dmenu -p "Clipboard History" | cliphist decode | wl-copy
    bind = $mainMod, N, exec, swaync-client --toggle-panel
    bind = $mainMod SHIFT, N, exec, swaync-client --close-all
    bind = $mainMod ALT, L, exec, hyprlock
    bind = $mainMod CTRL SHIFT, B, exec, pkill -SIGUSR1 waybar

    # Volume controls (consolidated)
    bind = $mainMod, SLASH, exec, pamixer -t
    bind = $mainMod SHIFT, V, exec, pamixer -d 2
    bind = $mainMod SHIFT, B, exec, pamixer -i 2
    bind = , XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise --max-volume 120
    bind = , XF86AudioLowerVolume, exec, swayosd-client --output-volume lower --max-volume 120
    bind = , XF86AudioMute, exec, swayosd-client --output-volume mute-toggle
    bind = , XF86AudioMicMute, exec, swayosd-client --input-volume mute-toggle

    # Brightness controls (consolidated)
    bind = , XF86MonBrightnessUp, exec, swayosd-client --brightness +10
    bind = , XF86MonBrightnessDown, exec, swayosd-client --brightness -10
    bind = $mainMod, F3, exec, brightnessctl -d *::kbd_backlight set +33%
    bind = $mainMod, F2, exec, brightnessctl -d *::kbd_backlight set 33%-

    # Capslock indicator
    bind = , release Caps_Lock, exec, swayosd-client --caps-lock

    # Lid switch actions
    bindl = , switch:off:Lid Switch, exec, hyprctl keyword monitor "eDP-1, 1920x1080, 0x0, 1"
    bindl = , switch:on:Lid Switch, exec, hyprctl keyword monitor "eDP-1, disable"

    # Resize submap
    bind = $mainMod, R, submap, resize
    submap = resize
    binde = $mainMod, l, resizeactive, 30 0
    binde = $mainMod, h, resizeactive, -30 0
    binde = $mainMod, k, resizeactive, 0 -30
    binde = $mainMod, j, resizeactive, 0 30
    bind = , escape, submap, reset
    submap = reset

    # UI aesthetics
    blurls = notifications
    blurls = swayosd

    # Screenshot bindings
    bind = , Print, exec, flameshot gui --raw | wl-copy
    bind = SHIFT, Print, exec, flameshot gui --path ~/Pictures/screenshots
  '';
}
