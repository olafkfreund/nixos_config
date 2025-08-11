_: {
  wayland.windowManager.hyprland.extraConfig = ''
    # System binds
    $mainMod = SUPER

    # Window/Workspace Navigation
    bind = ALT, TAB, cyclenext
    bind = ALT SHIFT, TAB, cyclenext, prev
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
    bind = $mainMod, TAB, workspace, previous

    # Application launchers
    bind = $mainMod, RETURN, exec, [float; size 50% 50%; center]foot
    bind = $mainMod CTRL, RETURN, exec, foot
    bind = $mainMod, space, exec, walker
    bind = $mainMod, backspace, exec, rofi-hyprkeys
    bind = $mainMod CTRL, Y, exec, [float]foot yai
    bind = $mainMod CTRL, M, exec, wdisplays
    bind = $mainMod, C, exec, thunderbird -calendar
    bind = $mainMod, A, exec, [float;notitle;]kitty --class album-art --hold mpris-album-art
    bind = $mainMod, E, exec, thunar
    bind = $mainMod, V, exec, cliphist list | rofi -dmenu | cliphist decode | wl-copy
    bind = $mainMod, equal, exec, [float; size 40% 50%; center]foot qalc
    bind = $mainMod SHIFT, Escape, exec, [float; size 60% 70%; center]foot htop

    # Special workspaces
    bind = $mainMod, S, togglespecialworkspace, slack
    bind = $mainMod SHIFT, S, togglespecialworkspace, magic
    bind = $mainMod, B, togglespecialworkspace, firefox
    bind = $mainMod, M, togglespecialworkspace, mail
    bind = $mainMod SHIFT, M, togglespecialworkspace, spotify
    bind = $mainMod, T, togglespecialworkspace, scratchpad
    bind = $mainMod, D, togglespecialworkspace, discord
    bind = $mainMod SHIFT, W, exec, weather-popup
    bind = $mainMod, Escape, killactive, title:^(Weather - London)$

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


    # Moving windows within workspace
    bind = $mainMod SHIFT, h, movewindow, l
    bind = $mainMod SHIFT, l, movewindow, r
    bind = $mainMod SHIFT, k, movewindow, u
    bind = $mainMod SHIFT, j, movewindow, d
    bind = $mainMod SHIFT, c, centerwindow, none

    # Window swapping (modern pattern)
    bind = $mainMod CTRL, h, swapwindow, l
    bind = $mainMod CTRL, l, swapwindow, r
    bind = $mainMod CTRL, k, swapwindow, u
    bind = $mainMod CTRL, j, swapwindow, d

    # Window management
    bind = $mainMod, Q, killactive
    bind = $mainMod, F, fullscreen, 0
    bind = $mainMod SHIFT, F, togglefloating
    bind = $mainMod ALT, P, pin
    bind = $mainMod, Y, exec, hyprctl keyword general:layout "dwindle"
    bind = $mainMod, U, exec, hyprctl keyword general:layout "master"

    # Window opacity controls
    bind = $mainMod ALT, equal, exec, hyprctl setprop active alpha 0.9
    bind = $mainMod ALT, minus, exec, hyprctl setprop active alpha 0.8
    bind = $mainMod ALT, 0, exec, hyprctl setprop active alpha 1.0

    # Window splitting (manual tiling)
    bind = $mainMod ALT, h, layoutmsg, preselect l
    bind = $mainMod ALT, j, layoutmsg, preselect d
    bind = $mainMod ALT, k, layoutmsg, preselect u
    bind = $mainMod ALT, l, layoutmsg, preselect r

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
    bind = $mainMod SHIFT, S, exec, foot -e d
    bind = $mainMod SHIFT, I, exec, open-clip
    bind = $mainMod, N, exec, swaync-client --toggle-panel
    bind = $mainMod SHIFT, N, exec, swaync-client --close-all
    bind = $mainMod, L, exec, hyprlock

    # Gaming mode toggle (disables compositor effects for performance)
    bind = $mainMod CTRL, G, exec, hyprctl keyword decoration:drop_shadow false && hyprctl keyword decoration:blur:enabled false && hyprctl keyword animations:enabled false && notify-send "Gaming Mode" "Enabled"
    bind = $mainMod CTRL ALT, G, exec, hyprctl keyword decoration:drop_shadow true && hyprctl keyword decoration:blur:enabled true && hyprctl keyword animations:enabled true && notify-send "Gaming Mode" "Disabled"

    # Media controls
    bind = , XF86AudioPlay, exec, playerctl play-pause
    bind = , XF86AudioNext, exec, playerctl next
    bind = , XF86AudioPrev, exec, playerctl previous
    bind = $mainMod, P, exec, playerctl play-pause
    bind = $mainMod SHIFT, period, exec, playerctl next
    bind = $mainMod SHIFT, comma, exec, playerctl previous

    # Power management
    bind = $mainMod SHIFT, End, exec, systemctl suspend
    bind = $mainMod SHIFT, Delete, exec, systemctl poweroff
    bind = $mainMod SHIFT, Insert, exec, systemctl reboot

    # Development shortcuts
    bind = $mainMod SHIFT, Return, exec, code
    bind = $mainMod SHIFT, T, exec, [float; size 80% 80%; center]foot
    bind = $mainMod CTRL, T, exec, [float; size 60% 40%; center]foot -e tmux

    # Network management
    bind = $mainMod CTRL, W, exec, [float; size 50% 60%; center]foot nmtui

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
    bind = CTRL, Print, exec, flameshot full --path ~/Pictures/screenshots

    # Modern mouse navigation (forward/back buttons)
    bind = , mouse:276, workspace, e+1
    bind = , mouse:275, workspace, e-1
    bindm = $mainMod, mouse:272, focuswindow

    # Modern touchpad/mouse gestures
    bind = , swipe:3:right, workspace, e-1
    bind = , swipe:3:left, workspace, e+1
    bind = , swipe:3:up, exec, hyprctl dispatch workspace empty
    bind = , swipe:3:down, killactive

    # Enhanced window grouping/tabbing (modern productivity)
    bind = $mainMod, W, togglegroup
    bind = $mainMod SHIFT, W, lockgroups
    bind = $mainMod CTRL, TAB, changegroupactive, f
    bind = $mainMod CTRL SHIFT, TAB, changegroupactive, b

    # Visual group indicators
    bind = $mainMod ALT, 1, exec, hyprctl setprop active group:set:1
    bind = $mainMod ALT, 2, exec, hyprctl setprop active group:set:2

    # Smart window sizing (golden ratio + standard sizes)
    bind = $mainMod SHIFT, equal, exec, hyprctl dispatch resizeactive exact 1920 1080
    bind = $mainMod SHIFT, minus, exec, hyprctl dispatch resizeactive exact 1280 720
    bind = $mainMod SHIFT, 0, exec, hyprctl dispatch resizeactive exact 50% 50%
    bind = $mainMod ALT, G, exec, hyprctl dispatch resizeactive exact 61.8% 100%

    # Dynamic workspace management
    bind = $mainMod CTRL, N, exec, hyprctl dispatch workspace empty
    bind = $mainMod CTRL, X, exec, hyprctl dispatch workspace previous

    # Performance toggles (quick controls)
    bind = $mainMod SHIFT, G, exec, hyprctl keyword decoration:blur:enabled $([ $(hyprctl getoption decoration:blur:enabled -j | jq '.int') = 1 ] && echo false || echo true) && notify-send "Hyprland" "Blur toggled"
    bind = $mainMod SHIFT, A, exec, hyprctl keyword animations:enabled $([ $(hyprctl getoption animations:enabled -j | jq '.int') = 1 ] && echo false || echo true) && notify-send "Hyprland" "Animations toggled"

    # GPU monitoring and system performance
    bind = $mainMod CTRL, M, exec, [float; size 70% 80%; center]foot -e nvtop
    bind = $mainMod SHIFT, M, exec, [float; size 70% 80%; center]foot -e htop

    # Emergency and debugging shortcuts
    bind = $mainMod CTRL SHIFT, R, exec, hyprctl reload && notify-send "Hyprland" "Configuration reloaded"
    bind = $mainMod CTRL SHIFT, K, exec, hyprctl kill
    bind = $mainMod CTRL SHIFT, E, exec, hyprctl dispatch exit

    # Debug information (copy to clipboard)
    bind = $mainMod SHIFT, D, exec, hyprctl activewindow -j | wl-copy && notify-send "Debug" "Active window info copied"
    bind = $mainMod SHIFT, I, exec, hyprctl version | wl-copy && notify-send "Debug" "Hyprland version copied"

    # Enhanced clipboard with clear option
    bind = $mainMod CTRL, V, exec, cliphist clear && notify-send "Clipboard" "History cleared"

    # Workspace-specific layouts (productivity optimization)
    bind = $mainMod ALT, 1, exec, hyprctl keyword general:layout dwindle && hyprctl dispatch workspace 1
    bind = $mainMod ALT, 2, exec, hyprctl keyword general:layout master && hyprctl dispatch workspace 2
    bind = $mainMod ALT, 3, exec, hyprctl keyword general:layout dwindle && hyprctl dispatch workspace 3

    # Focus window under cursor (modern UX)
    bind = $mainMod CTRL, mouse:272, focuswindow
  '';
}
