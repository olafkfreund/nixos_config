{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.desktop.sway;
in {
  options.desktop.sway = {
    enable = mkEnableOption {
      default = false;
      description = "sway";
    };
  };
  config = mkIf cfg.enable {
    wayland.windowManager.sway = {
      enable = true;
      xwayland = true;
      wrapperFeatures.gtk = true;
      systemd = {
        enable = true;
        xdgAutostart = true;
      };
      extraConfig = ''
        output HEADLESS-1 pos 0 0 res 2560x1440
      '';
      extraSessionCommands = ''
        export SDL_VIDEODRIVER=wayland
        export QT_QPA_PLATFORM=wayland
        export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
        export _JAVA_AWT_WM_NONREPARENTING="1"
        export MOZ_ENABLE_WAYLAND="1"
        # export WLR_BACKENDS="headless,libinput"
        # export WLR_LIBINPUT_NO_DEVICES="1"
        export GTK_THEME=Gruvbox-Dark-B-LB      # Set GTK theme
        export GDK_BACKEND="wayland,x11"
        export QT_QPA_PLATFORM=wayland          # Set Qt platform to Wayland
        export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"  # Disable window decorations in Qt Wayland
        export QT_AUTO_SCREEN_SCALE_FACTOR="1"    # Enable automatic screen scaling for Qt
        export QT_ENABLE_HIGHDPI_SCALING="1"      # Enable high DPI scaling for QT
        # NixOS-specific settings
        export NIXOS_WAYLAND="1"                 # Enable Wayland support in NixOS
        export NIXOS_OZONE_W="1"                 # Enable Ozone Wayland support in NixOS
        export ELECTRON_OZONE_PLATFORM_HINT=auto  # Set Electron to automatically choose between Wayland and X11
      '';
      config = {
        # modifier = "Mod4";
        bars = [
          {command = "\${pkgs.waybar}/bin/waybar";}
        ];
        terminal = "foot";
        menu = "rofi -show drun";
        startup = [
          {command = "foot";}
          {command = "wayvnc 0.0.0.0";}
          {
            command = "systemctl --user restart waybar";
            always = true;
          }
          {command = "gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'";}
          {command = "gsettings set org.gnome.desktop.interface icon-theme 'Gruvbox-Material-Dark'";}
          {command = "gsettings set org.gnome.desktop.interface gtk-theme 'Gruvbox-Material-Dark'";}
          {command = "gnome-keyring-daemon --start --components=secrets";}
          {command = "wl-paste --type text --watch cliphist store";}
          {command = "wl-paste --type image --watch cliphist store";}
          {command = "kdeconnectd";}
          {command = "playerctld daemon";}
          {command = "polkit-agent-helper-1";}
          {command = ''$keybinds = $(hyprkeys -bjl | jq '.Binds | map(.Bind + " -> " + .Dispatcher + ", " + .Command)'[] -r)'';}
          {command = ''$execs = $(hyprkeys -aj | jq '.AutoStart | map("[" + .ExecType + "] " + .Command)'[] -r)'';}
          {command = "swww-daemon init & sleep 0.1 & swww img /home/olafkfreund/Pictures/wallpapers/gruvbox/hypr/gruv-portal-cake.png --transition-type center";}
        ];
        # output = {
        #   "*".bg = "/home/olafkfreund/Pictures/wallpapers/gruvbox/hypr/gruv-portal-cake.png fill";
        #   "*".scale = "1";
        # };

        focus = {followMouse = "always";};
        gaps = {
          inner = 5;
          outer = 5;
          smartGaps = true;
          smartBorders = "on";
        };
        colors = rec {
          background = "#504945";
          unfocused = {
            text = "#ebdbb2";
            border = "#fe8019";
            background = "#504945";
            childBorder = "#fe8019";
            indicator = "#504945";
          };
          focusedInactive = unfocused;
          urgent =
            unfocused
            // {
              text = "#ebdbb2";
              border = "#fb4934";
              childBorder = "#fb4934";
            };
          focused =
            unfocused
            // {
              childBorder = "#8ec07c";
              border = "#8ec07c";
              background = "#282828";
              text = "#ebdbb2";
            };
        };
        window = {
          border = 2;
          titlebar = false;
        };
      };
    };
  };
}
