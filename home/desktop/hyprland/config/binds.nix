{ config, pkgs, ...}:

{
   wayland.windowManager.hyprland.extraConfig = ''
   # System binds #
      $mainMod = SUPER

      #Hyprexpo
      bind = ALT, TAB, hyprexpo:expo, toggle # can be: toggle, off/disable or on/enable

      #Apps
      bind = $mainMod, E, exec, [float]foot yazi
      bind = $mainMod, T, exec, foot
      bind = $mainMod CTRL, M, exec, monitors
      bind = $mainMod, backspace, exec, ~/.config/rofi/launchers/type-2/hyprkeys.sh
      bind = $mainMod, RETURN, exec, wezterm start
      bind = $mainMod, space, exec, ~/.config/rofi/launchers/type-7/launcher.sh
      bind = $mainMod SHIFT, P, exec, $HOME/.config/rofi/applets/bin/screenshot.sh
      bind = $mainMod SHIFT, I, exec, $HOME/.config/rofi/applets/bin/clipboard.sh
      bind = $mainMod, SLASH, exec, pamixer -t
      bind = $mainMod, N, exec, dunstctl history-pop
      bind = $mainMod SHIFT, N, exec, dunstctl close-all

      bind = , XF86AudioRaiseVolume, exec, swayosd-client --output-volume=raise
      bind = , XF86AudioLowerVolume, exec, swayosd-client --output-volume=lower
      bind = , XF86AudioMute, exec, swayosd-client --output-volume mute-toggle
      bind = , XF86MonBrightnessUp, exec, brightnessctl set 30+
      bind = , XF86MonBrightnessDown, exec, brightnessctl set 30-
      bind = , XF86AudioRaiseVolume, exec, amixer set Master 5%+
      bind = , XF86AudioLowerVolume, exec, amixer set Master 5%-
      bind = , XF86AudioMute, exec, amixer set Master toggle
      
      bind = , XF86AudioMute, exec, swayosd-client --output-volume mute-toggle
      bind = , XF86AudioMicMute, exec, swayosd-client --input-volume mute-toggle
      bind = , XF86AudioRaiseVolume, exec, swayosd-client --output-volume 5
      bind = , XF86AudioLowerVolume, exec, swayosd-client --output-volume -5
      bind = , XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise --max-volume 120
      bind = , XF86AudioLowerVolume, exec, swayosd-client --output-volume lower --max-volume 120
      bind = , XF86MonBrightnessUp, exec, swayosd-client --brightness raise
      bind = , XF86MonBrightnessDown, exec, swayosd-client --brightness lower
      bind = , XF86MonBrightnessUp,  exec, swayosd-client --brightness +10
      bind = , XF86MonBrightnessDown, exec, swayosd-client --brightness -10
      bind = , release Caps_Lock, exec, swayosd-client --caps-lock

      bind = $mainMod, F3, exec, brightnessctl -d *::kbd_backlight set +33%
      bind = $mainMod, F2, exec, brightnessctl -d *::kbd_backlight set 33%-"

      bindm = $mainMod, mouse:272, movewindow
      bindm = $mainMod, mouse:273, resizewindow

      bind = $mainMod, S, togglespecialworkspace, magic
      bind = $mainMod, M, togglespecialworkspace, mail
      bind = $mainMod, W, killactive
      bind = $mainMod, F, fullscreen, 1 #maximize window
      
      bind = $mainMod, F, togglefloating
      bind = $mainMod, Y, exec, hyprctl keyword general:layout "dwindle"
      bind = $mainMod, U, exec, hyprctl keyword general:layout "master"
      bind = $mainMod, I, layoutmsg, cyclenext
      bind = $mainMod, O, layoutmsg, swapwithmaster master
      bind = $mainMod, P, pin
      
      bind = $mainMod, h, movefocus, l
      bind = $mainMod, l, movefocus, r
      bind = $mainMod, k, movefocus, u
      bind = $mainMod, j, movefocus, d

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

      bind = $mainMod, BRACKETLEFT, layoutmsg, rollnext
      bind = $mainMod, BRACKETRIGHT, layoutmsg, rollprev

      bind = $mainMod, mouse_down, workspace, e-1
      bind = $mainMod, mouse_up, workspace, e+1
      
      # group management
      bind = $mainMod, G, togglegroup,
      bind = $mainMod SHIFT, G, moveoutofgroup,
      bind = ALT, left, changegroupactive, b
      bind = ALT, right, changegroupactive, f 

      bind = $mainMod ALT, H, movetoworkspace, special:hidden
      bind = $mainMod ALT, H, togglespecialworkspace, hidden
      bind = $mainMod ALT, L, exec, hyprlock

      bind = $mainMod SHIFT, M, movetoworkspace, special:mail
      bind = $mainMod SHIFT, S, movetoworkspace, special:magic

      binde = $mainMod SHIFT, V, exec, pamixer -d 2
      binde = $mainMod SHIFT, B, exec, pamixer -i 2


      bind = $mainMod SHIFT, U, layoutmsg, orientationcycle
      bind = $mainMod SHIFT, I, layoutmsg, cycleprev
      bind = $mainMod SHIFT, O, layoutmsg, focusmaster auto

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

      bind = $mainMod_SHIFT, h,movewindow,l
      bind = $mainMod_SHIFT, l,movewindow,r
      bind = $mainMod_SHIFT, k,movewindow,u
      bind = $mainMod_SHIFT, j,movewindow,d
      bind = $mainMod_SHIFT, c,centerwindow,none

      bind = $mainMod, R, submap, resize #resize mode
      submap = resize
      binde = $mainMod, l, resizeactive, 30 0
      binde = $mainMod, h, resizeactive, -30 0
      binde = $mainMod, k, resizeactive, 0 -30
      binde = $mainMod, j, resizeactive, 0 30
      bind = , escape, submap, reset #reset mode
      submap = reset

      bind = $mainMod SPACE, l, workspace, r+1
      bind = $mainMod SPACE, h, workspace, r-1
      bind = $mainMod CTRL SHIFT, B, exec, pkill -SIGUSR1 waybar

      bind = Control_SHIFT, M, togglespecialworkspace, spotify

      bindl = , switch:off:Lid Switch,exec,hyprctl keyword monitor "eDP-1, 1920x1080, 0x0, 1"
      bindl = , switch:on:Lid Switch,exec,hyprctl keyword monitor "eDP-1, disable"

      blurls = notifications
      blurls = swayosd
  '';
}
