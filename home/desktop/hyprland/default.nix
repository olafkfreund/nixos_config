{
  config,
  inputs,
  pkgs,
  host,
  username,
  ...
}: let
  animations.fast = true;
  animations.moving = false;
  animations.high = false;
  decoration.rounding.more.blur = false;
  decoration.rounding.all.blur = false;
  decoration.no.rounding.blur = true;
  gaps-big-no-border = true;
  gaps-big-border = false;
  inherit
    (
      import ../../../hosts/${host}/variables.nix
    )
    laptop_monitor
    external_monitor
    ;
in {
  imports = [
    ./hypr_dep.nix
    ./hyprlock.nix
    ./hypridle.nix
    ./scripts/packages.nix
  ];

  # hyprpaper
  home = {
  # file = {
  #   ".config/hypr/hyprpaper.conf".source = ../config/hypr/hyprpaper.conf;
  # };

  # make stuff work on wayland
  sessionVariables = {
    XDG_CACHE_HOME = "\${HOME}/.cache";
    XDG_CONFIG_HOME = "\${HOME}/.config";
    XDG_BIN_HOME = "\${HOME}/.local/bin";
    XDG_DATA_HOME = "\${HOME}/.local/share";
    MOZ_ENABLE_WAYLAND = "1";
    # NIXOS_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
    };
  };

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    systemd = {
      variables = ["--all"];
      extraCommands = [
        "systemctl --user stop graphical-session.target"
        "systemctl --user start hyprland-session.target"
      ];
    };
    xwayland.enable = true;
    plugins = [
      pkgs.hyprlandPlugins.hyprexpo
      pkgs.hyprlandPlugins.csgo-vulkan-fix
      pkgs.hyprlandPlugins.hyprfocus
    ];
    extraConfig = ''
      #monitor=,preferred,auto, 1
      #wsbind=1,eDP-1

      ${laptop_monitor}
      ${external_monitor}

      xwayland {
        force_zero_scaling = true
      }


      exec-once = hyprctl setcursor Bibata-Modern-Ice 1
      exec-once = gnome-keyring-daemon --start --components=secrets
      exec-once = polkit-kde-authentication-agent-1
      exec-once = kdeconnectd
      exec-once = kdeconnect-indicator
      exec-once = dbus-update-activation-environment --systemd --all
      exec-once = systemctl --user import-environment PATH WAYLAND_DISPLAY XDG_CURRENT_DESKTOP & systemctl --user restart xdg-desktop-portal.service
      exec-once = polkit-agent-helper-1
      exec-once = gsettings set org.gnome.desktop.interface ursor-theme "Bibata-Modern-Ice"
      exec-once = gsettings set org.gnome.desktop.interface icon-theme "Gruvbox-Plus-Dark"
      exec-once = gsettings set org.gnome.desktop.interface gtk-theme "Gruvbox-Dark-BL-LB"

      exec-once = killall -q waybar;sleep .5 && waybar
      exec-once = swayosd-server
      exec-once = sudo swayosd-libinput-backend
      exec-once = killall dunst;sleep .5 && dunst
      exec-once = kdeconnect-cli
      exec-once = playerctld daemon
      exec-once = killall swww;sleep .5& swww-daemon --format xrgb
      exec-once = hypridle
      exec-once = nm-applet --indicator
      exec-once = blueman-applet

      exec-once = wl-clipboard-history -t
      exec-once = wl-paste --type text --watch cliphist store #Stores only text data
      exec-once = wl-paste --type image --watch cliphist store #Stores only image data when imaged copied

      exec-once = [workspace special:spotify] spotify
      exec-once = [workspace 1 silent] google-chrome-stable
      exec-once = [workspace 2 silent] firefox
      exec-once = [workspace 3 silent] foot
      exec-once = [workspace 4 silent] slack
      exec-once = [workspace 5 silent] ferdium
      exec-once = [workspace 6 silent] obsidian
      exec-once = [workspace 8 silent] 1password
      exec-once = [workspace 3 silent] wezterm start --always-new-process
      exec-once = $keybinds = $(hyprkeys -bjl | jq '.Binds | map(.Bind + " -> " + .Dispatcher + ", " + .Command)'[] -r)
      exec-once = $execs = $(hyprkeys -aj | jq '.AutoStart | map("[" + .ExecType + "] " + .Command)'[] -r)

      # Env variables
      env = EDITOR="nvim";
      env = BROWSER="google-chrome-stable";
      env = TERMINAL="foot";

      env = SDL_VIDEODRIVER, x11
      env = XDG_CURRENT_DESKTOP,Hyprland
      env = XDG_SESSION_TYPE,wayland
      env = XDG_SESSION_DESKTOP,Hyprland

      env = XCURSOR_THEME,Bibata-Modern-Ice
      env = XCURSOR_SIZE,16

      # env = ELECTRON_OZONE_PLATFORM_HINT,wayland
      # env = OZONE_PLATFORM,wayland
      env = CLUTTER_BACKEND,wayland

      #GTK
      env = GDK_BACKEND,wayland,x11,*
      env = GTK_THEME,Gruvbox-Dark-B-LB
      # env = GDK_DPI_SCALE,1
      # env = GDK_SCALE,1

      #QT
      env = QT_QPA_PLATFORM,wayland
      env = QT_WAYLAND_DISABLE_WINDOWDECORATION, 1
      env = QT_AUTO_SCREEN_SCALE_FACTOR, 1
      env = QT_ENABLE_HIGHDPI_SCALING, 1

      #Firefox & Thunderbird
      env = MOZ_ENABLE_WAYLAND, 1

      #Nvidia
      # env = GBM_BACKEND,nvidia-drm
      # env = LIBVA_DRIVER_NAME,nvidia
      # env = WLR_RENDERER,vulkan
      # put everything onto nvidia card
      # env = __NV_PRIME_RENDER_OFFLOAD, 1
      # env = __NV_PRIME_RENDER_OFFLOAD_PROVIDER, NVIDIA-G0
      # env = __GLX_VENDOR_LIBRARY_NAME, nvidia
      # env = __VK_LAYER_NV_optimus, NVIDIA_only

      #NIXOS
      env = NIXOS_WAYLAND, 1
      env = NIXOS_OZONE_WL, 1
      # Electron
      # ELECTRON_OZONE_PLATFORM_HINT = "wayland";



      input {
          kb_layout=gb
          kb_variant=
          kb_model=
          kb_options=
          kb_rules=
          follow_mouse=1
          touchpad {
            natural_scroll=no
          }
      }

      misc {
        enable_swallow=true
        swallow_regex =^(kitty)$
        layers_hog_keyboard_focus=true
        vfr=true
        vrr=0
        animate_mouse_windowdragging=true
        mouse_move_focuses_monitor = true

      }

      general {
          sensitivity=1.0 # for mouse cursor
          ${
        if gaps-big-no-border == true
        then ''
          gaps_in = 1
          gaps_out = 1
          border_size = 0
        ''
        else if gaps-big-border == true
        then ''
          gaps_in = 10
          gaps_out = 14
          border_size = 0
        ''
        else ''
          gaps_in=4
          gaps_out=8
          border_size=2
        ''
      }
          no_border_on_floating=0
          col.active_border = rgba(${config.colorScheme.palette.base05}FF) rgba(${config.colorScheme.palette.base05}FF) 45deg
          col.inactive_border = rgba(${config.colorScheme.palette.base00}11) rgba(${config.colorScheme.palette.base00}11) 45deg
          apply_sens_to_raw=0
          resize_on_border=true
          layout = dwindle
      }

      ${
        if decoration.rounding.more.blur == true
        then ''
          decoration {
            rounding = 0
            blur {
                enabled = true
                size = 12
                passes = 6
                new_optimizations = on
                ignore_opacity = true
                xray = true
            }
            active_opacity = 1.0
            inactive_opacity = 0.6
            fullscreen_opacity = 1.0

            drop_shadow = true
            shadow_range = 30
            shadow_render_power = 3
            col.shadow = 0x66000000
          }
        ''
        else if decoration.rounding.all.blur == true
        then ''
            decoration {
          rounding = 10
          blur {
              enabled = true
              size = 12
              passes = 4
              new_optimizations = on
              ignore_opacity = true
              xray = true
          }
          active_opacity = 1
          inactive_opacity = 0.6
          fullscreen_opacity = 0.9

          drop_shadow = true
          shadow_range = 30
          shadow_render_power = 3
          col.shadow = 0x66000000
          }
        ''
        else if decoration.no.rounding.blur == true
        then ''
          decoration {
          rounding = 0
          blur {
              enabled = false
              size = 6
              passes = 2
              new_optimizations = on
              ignore_opacity = true
              xray = true
          }
          active_opacity = 1.0
          inactive_opacity = 1.0
          fullscreen_opacity = 1.0

          drop_shadow = true
          shadow_range = 30
          shadow_render_power = 3
          col.shadow = 0x66000000

          }
        ''
        else ''
          decoration {
              blur {
                enabled = yes
                special = true
                size = 6
                passes = 3
                new_optimizations = true
                ignore_opacity = true
                xray = false
              }
          rounding=14
          drop_shadow=1
          shadow_ignore_window=true
          shadow_offset=7 7
          shadow_range=15
          shadow_render_power=4
          shadow_scale=0.99
          col.shadow=rgba(000000BB)
          dim_inactive=true
          dim_strength=0.9
          active_opacity= 0.92
          inactive_opacity= 0.76
          }
        ''
      }

      animations {
          enabled=true
          ${
        if animations.fast == true
        then ''
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
          animation = windows, 1, 3, md3_decel, popin 60%
          animation = border, 1, 10, default
          animation = fade, 1, 2.5, md3_decel
          animation = workspaces, 1, 3.5, easeOutExpo, slide
          animation = specialWorkspace, 1, 3, md3_decel, slidevert
        ''
        else if animations.moving == true
        then ''
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
        ''
        else if animations.high == true
        then ''
          bezier = wind, 0.05, 0.9, 0.1, 1.05
          bezier = winIn, 0.1, 1.1, 0.1, 1.1
          bezier = winOut, 0.3, -0.3, 0, 1
          bezier = liner, 1, 1, 1, 1
          animation = windows, 1, 6, wind, slide
          animation = windowsIn, 1, 6, winIn, slide
          animation = windowsOut, 1, 5, winOut, slide
          animation = windowsMove, 1, 5, wind, slide
          animation = border, 1, 1, liner
          animation = borderangle, 1, 30, liner, loop
          animation = fade, 1, 10, default
          animation = workspaces, 1, 5, wind
        ''
        else ''
          animation=windows,1,3,default,slide
          animation=windowsMove,1,3,overshot
          animation=windowsOut,1,3,default,popin
          animation=border,1,1,default
          animation=fadeIn,1,5,default
          animation=fadeOut,1,5,default
          animation=fadeSwitch,1,10,default
          animation=border, 1, 10, overshot
          animation=borderangle, 1, 50, overshot, loop
        ''
      }
      }

      dwindle {
          pseudotile = true
          force_split = 2
          preserve_split = true
          no_gaps_when_only = false
      }



      gestures {
          workspace_swipe=yes
          workspace_swipe_fingers=3
      }
       plugin {
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

      # Window rules #
      windowrule = workspace current,title:MainPicker
      windowrule = workspace current,.blueman-manager-wrapped
      windowrule = workspace current,xdg-desktop-portal-gtk
      windowrule = workspace current,thunderbird

      # Rofi
      windowrulev2 = forceinput, class:(Rofi)$

      # Obsidian
      windowrulev2 = workspace 6, class:(obsidian)

      #Google Chrome
      windowrulev2 = workspace 1, class:(google-chrome-.*)
      windowrulev2 = workspace special:spotify, class:^(Spotify)$
      windowrulev2 = float,size 900 500,title:^(Choose Files)
      # windowrulev2 = workspace 2, class:(code.*)
      windowrulev2 = workspace 4, class:^(Edge)$

      #Pavucontrol
      windowrulev2 = float, class:(pavucontrol)
      windowrulev2 = size 1000 1000, class:(pavucontrol)
      windowrulev2 = center, class:(pavucontrol)

      #Telegram
      windowrulev2 = workspace 8, class:(org.telegram.desktop)
      windowrulev2 = size 970 480, class:(org.telegram.desktop), title:(Choose Files)
      windowrulev2 = center, class:(org.telegram.desktop), title:(Choose Files)

      windowrulev2 = float, class:(blueman-manager)
      windowrulev2 = center, class:(blueman-manager)
      windowrulev2 = float,class:^(nm-applet)$
      windowrulev2 = float,class:^(nm-connection-editor)$

      # Allow screen tearing for reduced input latency on some games.
      windowrulev2 = immediate, class:^(cs2)$
      windowrulev2 = immediate, class:^(steam_app_0)$
      windowrulev2 = immediate, class:^(steam_app_1)$
      windowrulev2 = immediate, class:^(steam_app_2)$
      windowrulev2 = immediate, class:^(.*)(.exe)$
      windowrulev2 = float, class:(xdg-desktop-portal-gtk)
      windowrulev2 = size 1345 720, class:(xdg-desktop-portal-gtk)
      windowrulev2 = center, class:(xdg-desktop-portal-gtk)

      #Xwayland hack
      windowrulev2 = opacity 0.0 override,class:^(xwaylandvideobridge)$
      windowrulev2 = noanim,class:^(xwaylandvideobridge)$
      windowrulev2 = noinitialfocus,class:^(xwaylandvideobridge)$
      windowrulev2 = maxsize 1 1,class:^(xwaylandvideobridge)$
      windowrulev2 = noblur,class:^(xwaylandvideobridge)$

      # Xdg
      windowrulev2 = float, class:^(xdg-desktop-portal-gtk)$
      windowrulev2 = size 900 500, class:^(xdg-desktop-portal-gtk)$
      windowrulev2 = dimaround, class:^(xdg-desktop-portal-gtk)$
      windowrulev2 = center, class:^(xdg-desktop-portal-gtk)$

      # System binds #
      $mainMod = SUPER

      #Hyprexpo
      bind = ALT, TAB, hyprexpo:expo, toggle # can be: toggle, off/disable or on/enable
      bind = , XF86AudioRaiseVolume, exec, swayosd-client --output-volume=raise
      bind = , XF86AudioLowerVolume, exec, swayosd-client --output-volume=lower
      bind = , XF86AudioMute, exec, swayosd-client --output-volume mute-toggle
      bind = ,XF86MonBrightnessUp, exec, brightnessctl set 30+
      bind = ,XF86MonBrightnessDown, exec, brightnessctl set 30-
      bind = ,XF86AudioRaiseVolume, exec, amixer set Master 5%+
      bind = ,XF86AudioLowerVolume, exec, amixer set Master 5%-
      bind = ,XF86AudioMute, exec, amixer set Master toggle
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
      bind = $mainMod, E, exec, wezterm start -- bash -c yazi
      bind = $mainMod, T, exec, wezterm start
      bind = $mainMod, M, exec, ~/.config/rofi/applets/bin/monitors.sh
      bind = $mainMod, P, pin
      bind = $mainMod, K&K, exec, kitty
      bind = $mainMod, K, exec, hyprctl kill
      # binds = $mainMod CTRL, S&U, exec, wezterm start -- bash -c system-tui
      # binds = $mainMod CTRL, L&G, exec, wezterm start -- bash -c lazygit
      # binds = $mainMod CTRL, K&9, exec, wezterm start -- bash -c k9s
      bind = $mainMod, S, togglespecialworkspace, magic
      bind = $mainMod, Z, exec, playerctl -p spotify previous
      bind = $mainMod, X, exec, playerctl -p spotify next
      bind = $mainMod, C, exec, playerctl -p spotify play-pause
      binde = $mainMod, V, exec, playerctl -p spotify volume 0.02-
      bind = $mainMod, backspace, exec, ~/.config/rofi/launchers/type-2/hyprkeys.sh
      binde = $mainMod, B, exec, playerctl -p spotify volume 0.02+
      bind = $mainMod, W, killactive
      bind = $mainMod, F&T, exec, foot
      bind = $mainMod, F, fullscreen, 1 #maximize window
      bind = $mainMod, Q, togglefloating
      bind = $mainMod, Y, exec, hyprctl keyword general:layout "dwindle" #switch to dwindle layout on fly
      bind = $mainMod, U, exec, hyprctl keyword general:layout "master" #switch to master layout on fly
      bind = $mainMod, I, layoutmsg, cyclenext
      bind = $mainMod, O, layoutmsg, swapwithmaster master
      bind = $mainMod, N, exec, dunstctl history-pop
      bind = $mainMod, RETURN, exec, [float] wezterm start
      bind = $mainMod, space, exec, ~/.config/rofi/launchers/type-2/launcher.sh
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
      bind = $mainMod,g,togglegroup
      bind = $mainMod,tab,changegroupactive
      bind = $mainMod, SLASH, exec, pamixer -t
      
      bind = $mainMod ALT, H, movetoworkspace, special:hidden
      bind = $mainMod ALT, H, togglespecialworkspace, hidden
      bind = $mainMod ALT, L, exec, hyprlock
      
      bind = $mainMod, backspace, exec, ~/.config/rofi/launchers/type-2/hyprkeys.sh
      bind = $mainMod SHIFT, N, exec, dunstctl close-all
      bind = $mainMod SHIFT, S, movetoworkspace, special:magic
      bind = $mainMod SHIFT, I, exec, $HOME/.config/rofi/applets/bin/clipboard.sh
      bind = $mainMod SHIFT, Z, exec, playerctl previous
      bind = $mainMod SHIFT, X, exec, playerctl next
      bind = $mainMod SHIFT, C, exec, playerctl play-pause
      binde = $mainMod SHIFT, V, exec, pamixer -d 2
      binde = $mainMod SHIFT, B, exec, pamixer -i 2
      bind = $mainMod SHIFT, F, fullscreen, 0 #true fullscreen
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

      binde = $mainMod_CTRL, l, resizeactive, 30 0
      binde = $mainMod_CTRL, h, resizeactive, -30 0
      binde = $mainMod_CTRL, k, resizeactive, 0 -30
      binde = $mainMod_CTRL, j, resizeactive, 0 30
      bind = $mainMod CTRL, P, pseudo
      bind = $mainMod SPACE, l, workspace, r+1
      bind = $mainMod SPACE, h, workspace, r-1
      bind = $mainMod CTRL SHIFT, B, exec, pkill -SIGUSR1 waybar

      bind = SHIFT ALT, P, exec, screenshotin
      bind = Control_SHIFT, M, togglespecialworkspace, spotify
      
      bindl = , switch:off:Lid Switch,exec,hyprctl keyword monitor "eDP-1, 1920x1080, 0x0, 1"
      bindl = , switch:on:Lid Switch,exec,hyprctl keyword monitor "eDP-1, disable"

      blurls = notifications
      blurls = swayosd
    '';
  };
}
