{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.desktop.gnome;
in
{
  config = mkIf (cfg.enable && cfg.keybindings.enable) {
    dconf.settings = {
      # Window management keybindings
      "org/gnome/desktop/wm/keybindings" = {
        # Window operations
        close = [ "<Super>q" "<Alt>F4" ];
        toggle-maximized = [ "<Super>m" ];
        toggle-fullscreen = [ "F11" ];
        minimize = [ "<Super>h" ];

        # Window switching
        switch-windows = [ "<Alt>Tab" ];
        switch-windows-backward = [ "<Shift><Alt>Tab" ];
        switch-applications = [ "<Super>Tab" ];
        switch-applications-backward = [ "<Shift><Super>Tab" ];

        # Workspace management
        switch-to-workspace-1 = [ "<Super>1" ];
        switch-to-workspace-2 = [ "<Super>2" ];
        switch-to-workspace-3 = [ "<Super>3" ];
        switch-to-workspace-4 = [ "<Super>4" ];
        switch-to-workspace-5 = [ "<Super>5" ];
        switch-to-workspace-6 = [ "<Super>6" ];
        switch-to-workspace-7 = [ "<Super>7" ];
        switch-to-workspace-8 = [ "<Super>8" ];
        switch-to-workspace-9 = [ "<Super>9" ];
        switch-to-workspace-10 = [ "<Super>0" ];

        # Move windows to workspaces
        move-to-workspace-1 = [ "<Super><Shift>1" ];
        move-to-workspace-2 = [ "<Super><Shift>2" ];
        move-to-workspace-3 = [ "<Super><Shift>3" ];
        move-to-workspace-4 = [ "<Super><Shift>4" ];
        move-to-workspace-5 = [ "<Super><Shift>5" ];
        move-to-workspace-6 = [ "<Super><Shift>6" ];
        move-to-workspace-7 = [ "<Super><Shift>7" ];
        move-to-workspace-8 = [ "<Super><Shift>8" ];
        move-to-workspace-9 = [ "<Super><Shift>9" ];
        move-to-workspace-10 = [ "<Super><Shift>0" ];

        # Workspace navigation
        switch-to-workspace-left = [ "<Super><Ctrl>Left" ];
        switch-to-workspace-right = [ "<Super><Ctrl>Right" ];
        switch-to-workspace-up = [ "<Super><Ctrl>Up" ];
        switch-to-workspace-down = [ "<Super><Ctrl>Down" ];

        # Move windows between workspaces
        move-to-workspace-left = [ "<Super><Shift><Ctrl>Left" ];
        move-to-workspace-right = [ "<Super><Shift><Ctrl>Right" ];
        move-to-workspace-up = [ "<Super><Shift><Ctrl>Up" ];
        move-to-workspace-down = [ "<Super><Shift><Ctrl>Down" ];

        # Window tiling (GNOME 45+)
        toggle-tiled-left = [ "<Super>Left" ];
        toggle-tiled-right = [ "<Super>Right" ];
        maximize = [ "<Super>Up" ];
        unmaximize = [ "<Super>Down" ];

        # Show desktop
        show-desktop = [ "<Super>d" ];

        # Panel operations
        panel-main-menu = [ "<Super>s" ];
        panel-run-dialog = [ "<Super>r" "<Alt>F2" ];
      };

      # Shell keybindings
      "org/gnome/shell/keybindings" = {
        # Activities overview
        toggle-overview = [ "<Super>" ];

        # Application launcher
        show-applications = [ "<Super>a" ];

        # Screenshot keybindings
        show-screenshot-ui = [ "Print" ];
        screenshot = [ "<Ctrl>Print" ];
        screenshot-window = [ "<Alt>Print" ];

        # Focus search in overview
        focus-active-notification = [ "<Super>n" ];

        # Toggle message tray
        toggle-message-tray = [ "<Super>v" ];

        # Switch to application shortcuts
        switch-to-application-1 = [ "<Super>1" ];
        switch-to-application-2 = [ "<Super>2" ];
        switch-to-application-3 = [ "<Super>3" ];
        switch-to-application-4 = [ "<Super>4" ];
        switch-to-application-5 = [ "<Super>5" ];
        switch-to-application-6 = [ "<Super>6" ];
        switch-to-application-7 = [ "<Super>7" ];
        switch-to-application-8 = [ "<Super>8" ];
        switch-to-application-9 = [ "<Super>9" ];
      };

      # Media keys
      "org/gnome/settings-daemon/plugins/media-keys" = {
        # Audio controls
        volume-up = [ "XF86AudioRaiseVolume" "<Super>equal" ];
        volume-down = [ "XF86AudioLowerVolume" "<Super>minus" ];
        volume-mute = [ "XF86AudioMute" ];
        mic-mute = [ "XF86AudioMicMute" ];

        # Media playback
        play = [ "XF86AudioPlay" ];
        pause = [ "XF86AudioPause" ];
        stop = [ "XF86AudioStop" ];
        next = [ "XF86AudioNext" ];
        previous = [ "XF86AudioPrev" ];

        # Display controls
        screen-brightness-up = [ "XF86MonBrightnessUp" ];
        screen-brightness-down = [ "XF86MonBrightnessDown" ];

        # System controls
        logout = [ "<Ctrl><Alt>Delete" ];
        screensaver = [ "<Super>l" ];

        # Calculator
        calculator = [ "XF86Calculator" "<Super>c" ];

        # Email
        email = [ "XF86Mail" ];

        # File manager
        home = [ "XF86Explorer" "<Super>e" ];

        # Web browser
        www = [ "XF86WWW" ];

        # Search
        search = [ "XF86Search" "<Super>f" ];
      };

      # Custom keybindings
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings" = {
        custom-keybinding-list = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/"
        ];
      };

      # Terminal shortcut
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
        binding = "<Ctrl><Alt>t";
        command = "foot";
        name = "Open Foot Terminal";
      };

      # File manager shortcut
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
        binding = "<Super>e";
        command = "nautilus";
        name = "Open File Manager";
      };

      # System monitor shortcut
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
        binding = "<Ctrl><Shift>Escape";
        command = "gnome-system-monitor";
        name = "Open System Monitor";
      };

      # Settings shortcut
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3" = {
        binding = "<Super>comma";
        command = "gnome-control-center";
        name = "Open Settings";
      };

      # Input method keybindings
      "org/gnome/desktop/input-sources" = {
        # Switch input source
        switch-input-source = [ "<Super>space" ];
        switch-input-source-backward = [ "<Shift><Super>space" ];
      };

      # Accessibility keybindings
      "org/gnome/settings-daemon/plugins/media-keys" = {
        # Toggle screen reader
        screenreader = [ "<Alt><Super>s" ];

        # Toggle on-screen keyboard
        on-screen-keyboard = [ "<Alt><Super>k" ];

        # Toggle magnifier
        magnifier = [ "<Alt><Super>equal" ];
        magnifier-zoom-in = [ "<Alt><Super>equal" ];
        magnifier-zoom-out = [ "<Alt><Super>minus" ];
      };
    };
  };
}
