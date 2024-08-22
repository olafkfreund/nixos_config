{
  config,
  inputs,
  pkgs,
  host,
  username,
  lib,
  ...
}: let
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
home = {
    # make stuff work on wayland
    sessionVariables = {
      XDG_CACHE_HOME = "\${HOME}/.cache";
      XDG_CONFIG_HOME = "\${HOME}/.config";
      XDG_BIN_HOME = "\${HOME}/.local/bin";
      XDG_DATA_HOME = "\${HOME}/.local/share";
      # MOZ_ENABLE_WAYLAND = "1";
      # NIXOS_WAYLAND = "1";
      # NIXOS_OZONE_WL = "1";
    };
  };

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    # systemd = {
    #   variables = ["--all"];
    #   extraCommands = [
    #     "systemctl --user stop graphical-session.target"
    #     "systemctl --user start hyprland-session.target"
    #   ];
    # };
    xwayland.enable = true;
    plugins = [
      pkgs.hyprlandPlugins.hyprexpo
      # pkgs.hyprlandPlugins.csgo-vulkan-fix
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


      # Set cursor theme
      exec-once = hyprctl setcursor Bibata-Modern-Ice 24

      # Start GNOME Keyring for secure storage of passwords and keys
      exec-once = gnome-keyring-daemon --start --components=secrets

      # exec-once = systemctl --user start graphical-session.target

      # Launch authentication agent for privilege escalation dialogs
      exec-once = sleep 10 & polkit-kde-authentication-agent-1

      # Start KDE Connect daemon and indicator for device integration
      exec-once = kdeconnectd
      # exec-once = kdeconnect-indicator

      # Update environment variables for proper Wayland integration
      exec-once = dbus-update-activation-environment --systemd --all
      exec-once = systemctl --user import-environment PATH WAYLAND_DISPLAY XDG_CURRENT_DESKTOP 

      # Restart XDG desktop portal for proper functionality
      exec-once = sleep 10 && systemctl --user restart xdg-desktop-portal.service

      # Start polkit agent helper
      exec-once = polkit-agent-helper-1

      # Set GNOME desktop interface settings
      exec-once = gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Ice"
      exec-once = gsettings set org.gnome.desktop.interface icon-theme "Gruvbox-Plus-Dark"
      exec-once = gsettings set org.gnome.desktop.interface gtk-theme "Gruvbox-Dark-BL-LB"

      # Launch Waybar (top bar)
      exec-once = killall -q waybar;sleep .5 & waybar

      # Start SwayOSD for on-screen display notifications
      exec-once = swayosd-server
      exec-once = sudo swayosd-libinput-backend

      # Launch notification daemon (Dunst)
      exec-once = killall dunst;sleep .5 & dunst

      # Start KDE Connect CLI
      exec-once = kdeconnect-cli

      # Launch playerctl daemon for media player control
      exec-once = playerctld daemon

      # Start wallpaper daemon (swww)
      exec-once = killall swww-daemon; sleep .5 & swww-daemon

      # Launch idle daemon
      exec-once = hypridle

      # Set up clipboard history
      exec-once = wl-paste --type text --watch cliphist store # Store text data
      exec-once = wl-paste --type image --watch cliphist store # Store image data

      # Generate keybinds and exec commands for reference
      exec-once = $keybinds = $(hyprkeys -bjl | jq '.Binds | map(.Bind + " -> " + .Dispatcher + ", " + .Command)'[] -r)
      exec-once = $execs = $(hyprkeys -aj | jq '.AutoStart | map("[" + .ExecType + "] " + .Command)'[] -r)

     # Environment variables for Hyprland configuration

      # General system settings
      env = EDITOR,"nvim"                    # Set default text editor to Neovim
      env = BROWSER,"google-chrome-stable"   # Set default web browser to Google Chrome
      env = TERMINAL,"foot"                  # Set default terminal emulator to Foot

      # Wayland-specific settings
      env = KITTY_DISABLE_WAYLAND,0          # Enable Wayland support for Kitty terminal
      env = XDG_CURRENT_DESKTOP,Hyprland     # Set current desktop environment to Hyprland
      env = XDG_SESSION_TYPE,wayland         # Set session type to Wayland
      env = CLUTTER_BACKEND,wayland          # Use Wayland backend for Clutter
      env = EGL_PLATFORM,wayland             # Set EGL platform to Wayland

      # Cursor settings
      env = XCURSOR_THEME,Bibata-Modern-Ice  # Set cursor theme
      env = XCURSOR_SIZE,24                  # Set X cursor size
      env = HYPRCURSOR_SIZE,24               # Set Hyprland cursor size

      # Graphics and display settings
      env = SDL_VIDEODRIVER,wayland          # Use wyaland video driver for SDL
      env = WLR_DRM_NO_ATOMIC,1              # Disable atomic mode setting for wlroots
      env = WLR_NO_HARDWARE_CURSORS,1        # Disable hardware cursors
      env = LIBVA_DRIVER_NAME,nvidia         # Set VAAPI driver to NVIDIA
      # env = WLR_RENDERER,vulkan              # Use Vulkan for wlroots rendering
      env = __GLX_VENDOR_LIBRARY_NAME,nvidia  # Set GLX vendor library to NVIDIA
      env = __GL_VRR_ALLOWED,1               # Enable VRR for NVIDIA
      env = __GL_GSYNC_ALLOWED,1             # Enable GSync for NVIDIA
      # env = NVD_BACKEND,direct               # Set NVIDIA Vulkan Direct backend
      env = __VK_LAYER_NV_optimus,NVIDIA_only     # Enable NVIDIA Optimus
      env = __NV_PRIME_RENDER_OFFLOAD,1      # Enable NVIDIA Prime Render __NV_PRIME_RENDER_OFFLOAD


      # GTK settings
      env = GDK_BACKEND,wayland,x11          # Set GTK backend to Wayland, fallback to X11
      env = GTK_THEME,Gruvbox-Dark-B-LB      # Set GTK theme

      # Qt settings
      env = QT_QPA_PLATFORM,wayland          # Set Qt platform to Wayland
      env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1  # Disable window decorations in Qt Wayland
      env = QT_AUTO_SCREEN_SCALE_FACTOR,1    # Enable automatic screen scaling for Qt
      env = QT_ENABLE_HIGHDPI_SCALING,1      # Enable high DPI scaling for Qt

      # Firefox and Thunderbird settings
      env = MOZ_ENABLE_WAYLAND,1             # Enable Wayland support for Mozilla applications

      # NixOS-specific settings
      env = NIXOS_WAYLAND,1                  # Enable Wayland support in NixOS
      env = NIXOS_OZONE_WL,1                 # Enable Ozone Wayland support in NixOS
      env = ELECTRON_OZONE_PLATFORM_HINT,auto  # Set Electron to automatically choose between Wayland and X11

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
        animate_mouse_windowdragging=true
        mouse_move_focuses_monitor = true
        initial_workspace_tracking = 0
        mouse_move_enables_dpms = true
        key_press_enables_dpms = false
        animate_manual_resizes = true
        middle_click_paste = true

      }

      general {
          sensitivity = 1.0
          gaps_in = 2
          gaps_out = 2
          border_size = 2
          layout = master
          resize_on_border = true
          col.active_border = rgb(${config.colorScheme.palette.base05})
          col.inactive_border = rgb(${config.colorScheme.palette.base09})

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
          active_opacity = 1.0
          inactive_opacity = 1.0
          fullscreen_opacity = 1.0
          drop_shadow = true
          shadow_range = 30
          shadow_render_power = 3
          col.shadow = 0x66000000
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
          no_gaps_when_only = false
      }

      master {
          no_gaps_when_only = false
          always_center_master = true
          smart_resizing = true
          new_status = master
          orientation = right
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
      # Workspace rules #
      workspace = 1,monitor:HDMI-A-1,default:true
      workspace = 2,monitor:HDMI-A-1
      workspace = 3,monitor:HDMI-A-1
      workspace = 4,monitor:HDMI-A-1
      workspace = 5,monitor:HDMI-A-1
      workspace = 6,monitor:eDP-1,default:true
      workspace = 7,monitor:eDP-1
      workspace = 8,monitor:eDP-1
      workspace = 9,monitor:eDP-1
      workspace = 10,monitor:eDP-1
      
      #Terminal rules
      windowrulev2 = float, class:(alacritty)
      windowrulev2 = size 1000 1000, class:(alacritty)
      windowrulev2 = float, class:(kitty)
      windowrulev2 = size 1000 1000, class:(kitty)
      windowrulev2 = float, class:(foot)
      windowrulev2 = size 1000 1000, class:(foot)
      windowrulev2 = float, class:(wezterm)
      windowrulev2 = size 1000 1000, class:(wezterm)

      # Window rules #
      windowrule = workspace current,title:MainPicker
      windowrule = workspace current,.blueman-manager-wrapped
      windowrule = workspace current,xdg-desktop-portal-gtk
      windowrule = workspace current,thunderbird

      # Rofi
      # windowrulev2 = forceinput, class:(Rofi)$

      # Obsidian
      windowrulev2 = float, class:(obsidian)

      #Google Chrome
      windowrulev2 = workspace 2, class:(google-chrome)
      windowrulev2 = workspace special:spotify, class:^(Spotify)$
      windowrulev2 = float,size 900 500,title:^(Choose Files)
      windowrulev2 = workspace 4, class:^(Edge)$

      #Pavucontrol
      windowrulev2 = float, class:(pavucontrol)
      windowrulev2 = size 1000 1000, class:(pavucontrol)
      windowrulev2 = center, class:(pavucontrol)

      #Telegram
      windowrulev2 = workspace 8, class:(org.telegram.desktop)
      windowrulev2 = size 970 480, class:(org.telegram.desktop), title:(Choose Files)
      windowrulev2 = center, class:(org.telegram.desktop), title:(Choose Files)
      
      #Gnome
      windowrulev2 = float, class:(org.gnome.*)
      windowrulev2 = size 1000 1000, class:(org.gnome.*)
      windowrulev2 = center, class:(org.gnome.*)

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

      #Apps
      bind = $mainMod, E, exec, [float]foot yazi
      bind = $mainMod, T, exec, foot
      bind = $mainMod, M, exec, monitors
      # bind = $mainMod, K, exec, hyprctl kill
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
  };
}
