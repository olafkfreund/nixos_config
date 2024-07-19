{
  config,
  inputs,
  pkgs,
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
in {
  imports = [
    ./hypr_dep.nix
    ./hyprlock.nix
    ./hypridle.nix
    ./scripts/packages.nix
    #./scripts/themechange.nix
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
      # SDL_VIDEODRIVER = "wayland";
      # XDG_CURRENT_DESKTOP = "Hyprland";
      # XDG_SESSION_TYPE = "wayland";
      # XDG_SESSION_DESKTOP = "Hyprland";
      # ELECTRON_OZONE_PLATFORM_HINT = "wayland";
      # OZONE_PLATFORM = "wayland";
      # CLUTTER_BACKEND = "wayland";
      # GDK_BACKEND = "wayland,x11,*";
      MOZ_ENABLE_WAYLAND = "1";
      # GBM_BACKEND = "nvidia-drm";
      # LIBVA_DRIVER_NAME = "nvidia";
      # NVD_BACKEND = "direct";
      NIXOS_WAYLAND = "1";
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
      # pkgs.hyprlandPlugins.hyprbars
      pkgs.hyprlandPlugins.hyprexpo
      pkgs.hyprlandPlugins.csgo-vulkan-fix
      # pkgs.hyprlandPlugins.hycov
      #pkgs.hyprlandPlugins.borders-plus-plus
    ];
    extraConfig = ''
      #laptop
      monitor = eDP-1,1920x1080@100,0x0,1
      #home
      # monitor = HDMI-A-1,3840x2160@60,0x0,1,bitdepth,10
      monitor = HDMI-A-1,3840x2160@120,0x0,1,bitdepth,10
      monitor = DP-3,3840x2160@120,0x0,1,bitdepth,10
      #monitor=,preferred,auto, 1
      #wsbind=1,eDP-1

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

      exec-once = waybar
      exec-once = swayosd-server
      exec-once = sudo swayosd-libinput-backend
      exec-once = dunst
      exec-once = kdeconnect-cli
      exec-once = playerctld daemon
      exec-once = swww init
      exec-once = pkill swww-daemon && swww-daemon --format xrgb
      # exec-once = start_wall
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

      env = SDL_VIDEODRIVER,wayland
      env = XDG_CURRENT_DESKTOP,Hyprland
      env = XDG_SESSION_TYPE,wayland
      env = XDG_SESSION_DESKTOP,Hyprland

      env = XCURSOR_THEME,Bibata-Modern-Ice
      env = XCURSOR_SIZE,16

      env = ELECTRON_OZONE_PLATFORM_HINT,wayland
      env = OZONE_PLATFORM,wayland
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
          gaps_in = 2
          gaps_out = 2
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
              enabled = true
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
          # layerrule = blur, waybar
          # layerrule = ignorezero, waybar
          layerrule = blur, notifications
          layerrule = ignorezero, notifications
          layerrule = blur, logout_dialog
          windowrule = stayfocused, emote
          windowrule = animation popin 95%, emote
          rounding=14
          drop_shadow=1
          shadow_ignore_window=true
          shadow_offset=7 7
          shadow_range=15
          shadow_render_power=4
          shadow_scale=0.99
          col.shadow=rgba(000000BB)
          dim_inactive=true
          dim_strength=0.1
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
      #     hycov {
      #       overview_gappo = 60 #gaps width from screen
      #       overview_gappi = 24 #gaps width from clients
      #       hotarea_size = 10 #hotarea size in bottom left,10x10
      #       enable_hotarea = 1 # enable mouse cursor hotarea
      #     },
           hyprexpo {
             columns = 3
             gap_size = 5
             bg_col = rgb(111111)
             workspace_method = center current # [center/first] [workspace] e.g. first 1 or center m+1
             enable_gesture = true # laptop touchpad, 4 fingers
             gesture_distance = 300 # how far is the "max"
             gesture_positive = true # positive = swipe down. Negative = swipe up.
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
      windowrulev2 = workspace 2, class:(code.*)
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

      bind = $mainMod, backspace, exec, ~/.config/rofi/launchers/type-2/hyprkeys.sh
      bind = $mainMod SHIFT, backspace, exec, ~/.config/rofi/launchers/type-2/hypr_exec.sh

      bindm = $mainMod, mouse:272, movewindow
      bindm = $mainMod, mouse:273, resizewindow

      bind = ,Print, exec, screenshootin
      bind = ,XF86MonBrightnessUp, exec, brightnessctl set 30+
      bind = ,XF86MonBrightnessDown, exec, brightnessctl set 30-
      bind = ,XF86AudioRaiseVolume, exec, amixer set Master 5%+
      bind = ,XF86AudioLowerVolume, exec, amixer set Master 5%-
      bind = ,XF86AudioMute, exec, amixer set Master toggle
      bind = $mainMod, F3, exec, brightnessctl -d *::kbd_backlight set +33%
      bind = $mainMod, F2, exec, brightnessctl -d *::kbd_backlight set 33%-"

      #OSD window
      bind=, XF86AudioRaiseVolume, exec, swayosd-client --output-volume=raise
      bind=, XF86AudioLowerVolume, exec, swayosd-client --output-volume=lower
      bind=, XF86AudioMute, exec, swayosd-client --output-volume mute-toggle
      bind=, release Caps_Lock, exec, swayosd-client --caps-lock

      bind=, XF86AudioMute, exec, swayosd-client --output-volume mute-toggle
      bind=, XF86AudioMicMute, exec, swayosd-client --input-volume mute-toggle
      bind=, XF86AudioRaiseVolume, exec, swayosd-client --output-volume 5
      bind=, XF86AudioLowerVolume, exec, swayosd-client --output-volume -5
      bind=, XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise --max-volume 120
      bind=, XF86AudioLowerVolume, exec, swayosd-client --output-volume lower --max-volume 120
      bind=, XF86MonBrightnessUp, exec, swayosd-client --brightness raise
      bind=, XF86MonBrightnessDown, exec, swayosd-client --brightness lower
      bind=, XF86MonBrightnessUp,  exec, swayosd-client --brightness +10
      bind=, XF86MonBrightnessDown, exec, swayosd-client --brightness -10

      #Kitty
      bind = $mainMod, E, exec, kitty --hold sh -c yazi
      bind = $mainMod, T, exec, kitty

      bind = $mainMod, space, exec, ~/.config/rofi/launchers/type-2/launcher.sh
      bind = $mainMod, RETURN, exec, kitty

      bind = $mainMod, N, exec, dunstctl history-pop
      bind = $mainMod SHIFT, N, exec, dunstctl close-all

      bind = CTRL, print, exec, grim -g \"$(slurp)\" - | wl-copy
      bind = ALT, print, exec, grim -g \"$(slurp)\" - | swappy -f -

      bind = $mainMod, P, pin
      #bind = $mainMod SHIFT, P, unpin

      bind = $mainMod ALT, H, movetoworkspace, special:hidden
      bind = $mainMod ALT, H, togglespecialworkspace, hidden

      bind = $mainMod, K, exec, hyprctl kill

      # Special workspace (scratchpad)
      bind = $mainMod, S, togglespecialworkspace, magic
      bind = $mainMod SHIFT, S, movetoworkspace, special:magic

      bind = , Insert, exec, $HOME/.config/rofi/applets/bin/clipboard.sh

      bind = $mainMod ALT, L, exec, hyprlock
      bind = $mainMod, h, movefocus, l
      bind = $mainMod, l, movefocus, r
      bind = $mainMod, k, movefocus, u
      bind = $mainMod, j, movefocus, d

      # Mediaplayer (spotify without SHIFT) binds and general volume control
      bind = $mainMod, Z, exec, playerctl -p spotify previous
      bind = $mainMod SHIFT, Z, exec, playerctl previous
      bind = $mainMod, X, exec, playerctl -p spotify next
      bind = $mainMod SHIFT, X, exec, playerctl next
      bind = $mainMod, C, exec, playerctl -p spotify play-pause
      bind = $mainMod SHIFT, C, exec, playerctl play-pause
      binde = $mainMod, V, exec, playerctl -p spotify volume 0.02-
      binde = $mainMod SHIFT, V, exec, pamixer -d 2
      binde = $mainMod, B, exec, playerctl -p spotify volume 0.02+
      binde = $mainMod SHIFT, B, exec, pamixer -i 2
      bind = $mainMod, SLASH, exec, pamixer -t

      #Spotify
      bind = Control_SHIFT, M, togglespecialworkspace, spotify

      # General window options
      bind = $mainMod, W, killactive
      bind = $mainMod, F, fullscreen, 1 #maximize window
      bind = $mainMod SHIFT, F, fullscreen, 0 #true fullscreen
      bind = $mainMod, Q, togglefloating
      bind = $mainMod, Y, exec, hyprctl keyword general:layout "dwindle" #switch to dwindle layout on fly
      bind = $mainMod, U, exec, hyprctl keyword general:layout "master" #switch to master layout on fly

      # Master layout control
      bind = $mainMod SHIFT, U, layoutmsg, orientationcycle
      bind = $mainMod, I, layoutmsg, cyclenext
      bind = $mainMod SHIFT, I, layoutmsg, cycleprev
      bind = $mainMod, O, layoutmsg, swapwithmaster master
      bind = $mainMod SHIFT, O, layoutmsg, focusmaster auto
      bind = $mainMod, BRACKETLEFT, layoutmsg, rollnext
      bind = $mainMod, BRACKETRIGHT, layoutmsg, rollprev

      # Dwindle layout control
      bind = $mainMod, P, pseudo

      # Move active window to a workspace with mainMod + SHIFT + [0-9]
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

      bind = $mainMod_SHIFT,h,movewindow,l
      bind = $mainMod_SHIFT,l,movewindow,r
      bind = $mainMod_SHIFT,k,movewindow,u
      bind = $mainMod_SHIFT,j,movewindow,d

      # Resize windows
      binde = $mainMod_CTRL, l, resizeactive, 30 0
      binde = $mainMod_CTRL, h, resizeactive, -30 0
      binde = $mainMod_CTRL, k, resizeactive, 0 -30
      binde = $mainMod_CTRL, j, resizeactive, 0 30

      # Switch workspaces with mainMod + [0-9]
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

      # Scroll through existing workspaces with mainMod + scroll
      bind = $mainMod, mouse_down, workspace, e-1
      bind = $mainMod, mouse_up, workspace, e+1

      # Waybar
      bind = $mainMod, B, exec, pkill -SIGUSR1 waybar

      # Switch workspaces relative to the active workspace with mainMod + CTRL + [←→]
      bind = $mainMod CTRL, l, workspace, r+1
      bind = $mainMod CTRL, h, workspace, r-1

      # move to the first empty workspace instantly with mainMod + CTRL + [↓]
      bind = $mainMod CTRL, down, workspace, empty
      bind = $mainMod,g,togglegroup
      bind = $mainMod,tab,changegroupactive

      # trigger when the switch is turning off
      bindl = , switch:off:Lid Switch,exec,hyprctl keyword monitor "eDP-1, 1920x1080, 0x0, 1"
      # trigger when the switch is turning on
      bindl = , switch:on:Lid Switch,exec,hyprctl keyword monitor "eDP-1, disable"

      # blurls = rofi
      # blurls = waybar
      # blurls = gtk-layer-shell
      blurls = notifications
      blurls = swayosd
    '';
  };
}
