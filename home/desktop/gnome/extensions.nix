{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.desktop.gnome;
in
{
  config = mkIf (cfg.enable && cfg.extensions.enable) {
    # GNOME Shell extensions configuration via dconf
    dconf.settings = {
      # Enable installed extensions
      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = [
          # Essential extensions UUIDs
          "user-theme@gnome-shell-extensions.gcampax.github.com"
          # "gsconnect@andyholmes.github.io" # Temporarily disabled due to build failure
          "dash-to-dock@micxgx.gmail.com"
          "appindicatorsupport@rgcjonas.gmail.com"
          "auto-accent-colour@Wartybix"
          "auto-move-windows@gnome-shell-extensions.gcampax.github.com"
          "bring-out-submenu-of-power-offlogout-button@gnome-shell-extensions.gcampax.github.com"
          "coverflow-alt-tab@gnome-shell-extensions.gcampax.github.com"
          "foresight@gnome-shell-extensions.gcampax.github.com"
          "move-to-next-screen@gnome-shell-extensions.gcampax.github.com"
          "Vitals@CoreCoding.com"
          "blur-my-shell@aunetx"
          "top-panel-logo@jmpegi.github.com"
          "workspace-indicator@gnome-shell-extensions.gcampax.github.com"
          "emoji-copy@felipeftn"
          "Gnofi@aylur"
          "windowsNavigator@gnome-shell-extensions.gcampax.github.com"
          "caffeine@patapon.info"
          "clipboard-indicator@tudmotu.com"
          "panel-osd@berend.de.schouwer.gmail.com"
          "quake-terminal@diegodario88.github.io"
          "tailscale-status@maxgallup.github.com"
          "tilingshell@ferrarodomenico.com"
          "user-themes@gnome-shell-extensions.gcampax.github.com"
          "bluetooth-battery@michalw.github.com"
          "BringOutSubmenuOfPowerOffLogoutButton@pratap.fastmail.fm"
        ];
      };

      # User Themes extension configuration
      "org/gnome/shell/extensions/user-theme" = {
        name = mkDefault (
          if cfg.theme.enable
          then "Gruvbox-Dark-BL"
          else "Adwaita"
        );
      };

      # GSConnect configuration (temporarily disabled due to build failure)
      # "org/gnome/shell/extensions/gsconnect" = {
      #   enabled = true;
      #   show-indicators = true;
      # };

      # Example configurations for popular extensions (commented out)

      # Dash to Dock configuration
      "org/gnome/shell/extensions/dash-to-dock" = {
        dock-position = "BOTTOM";
        extend-height = false;
        dock-fixed = true;
        dash-max-icon-size = 48;
        show-apps-at-top = true;
        show-trash = false;
        show-mounts = false;
        click-action = "previews";
        scroll-action = "cycle-windows";
        hot-keys = true;
        hotkeys-overlay = true;
        hotkeys-show-dock = true;
        transparency-mode = "DYNAMIC";
        customize-alphas = true;
        min-alpha = 0.2;
        max-alpha = 0.8;
      };

      # AppIndicator configuration
      "org/gnome/shell/extensions/appindicator" = {
        icon-brightness = 0.0;
        icon-contrast = 0.0;
        icon-opacity = 240;
        icon-saturation = 0.0;
        icon-size = 0;
        legacy-tray-enabled = true;
        tray-pos = "right";
      };

      # Vitals extension configuration
      "org/gnome/shell/extensions/vitals" = {
        hot-sensors = [
          "_processor_usage_"
          "_memory_usage_"
          "_temperature_processor_0_"
          "_network-rx_in_bytes_"
        ];
        position-in-panel = 2; # 0: left, 1: center, 2: right
        use-higher-precision = false;
        alphabetize = true;
        include-public-ip = true;
        include-static-info = false;
      };

      # Blur My Shell configuration
      "org/gnome/shell/extensions/blur-my-shell" = {
        brightness = 0.75;
        dash-opacity = 0.25;
        sigma = 30;
        static-blur = true;
      };

      # Accent-gtk-theme configuration
      "org/gnome/shell/extensions/accent-gtk-theme" = {
        blue-theme-light = "Gruvbox";
        set-link-gtk4 = true;
        set-theme-path = "home/olafkfreund/.local/share/themes";
      };

      # Caffeine configuration
      "org/gnome/shell/extensions/caffeine" = {
        enable-fullscreen = true;
        restore-state = true;
        show-indicator = true;
        show-notification = false;
      };

      # Auto Accent Colour configuration
      "org/gnome/shell/extensions/auto-accent-colour" = {
        hide-indicator = false;
        highlight-mode = true;
      };

      # Dim Background Windows configuration
      "org/gnome/shell/extensions/dim-background-windows" = {
        dim-background = true;
        dimming-enabled = true;
        toogle-shortcut = "<Super>g";
      };

      # Quake Terminal configuration
      "org/gnome/shell/extensions/quake-terminal" = {
        always-on-top = true;
        auto-hide-window = true;
        render-on-primary-monitor = true;
        render-on-current-monitor = false;
        terminal-id = "Alacritty.desktop";
        terminal-shortcut = "<Super>Return";
        vertical-size = 80;
      };

      # Tilling Shell configuration
      "org/gnome/shell/extensions/tilingshell" = {
        enable-autotilling = true;
        enable-snap-assist = false;
        enable-window-border = true;
        inner-gabs = 4;
        window-border-color = "rgb(154,153,150)";
      };

      # Gnofi configuration
      "org/gnome/shell/extensions/gnofi" = {
        window-hotkey = "<Super>space ";
      };

      # Clipboard Indicator configuration
      "org/gnome/shell/extensions/clipboard-indicator" = {
        cache-size = 50;
        clear-history = [ ];
        confirm-clear = false;
        display-mode = 0;
        enable-keybindings = true;
        history-size = 30;
        move-item-first = true;
        notify-on-copy = false;
        preview-size = 30;
        strip-text = false;
        topbar-preview-size = 10;
      };
    };

    # Note: Custom keybindings are defined in keybindings.nix to avoid conflicts

    # Install GNOME Shell extensions and extension-specific packages
    home.packages = with pkgs;
      [
        # Essential extensions (always installed when extensions are enabled)
        gnomeExtensions.user-themes
        # gnomeExtensions.gsconnect # Temporarily disabled due to build failure
        gnomeExtensions.tiling-shell
        # gnomeExtensions.ascii-emoji
        gnomeExtensions.dim-background-windows
        gnomeExtensions.just-perfection
        # gnomeExtensions.paperwm
        gnomeExtensions.quake-terminal
        gnomeExtensions.tailscale-status
        gnomeExtensions.auto-accent-colour
        gnomeExtensions.auto-move-windows
        gnomeExtensions.bring-out-submenu-of-power-offlogout-button
        gnomeExtensions.coverflow-alt-tab
        gnomeExtensions.foresight
        gnomeExtensions.move-to-next-screen
        gnomeExtensions.top-bar-organizer

        # Extension-specific packages that might be needed
        libnotify # For GSConnect
        lm_sensors # For system monitoring extensions
        curl # For weather extensions
        jq # For data processing
        xclip # For clipboard extensions
        wl-clipboard # For Wayland clipboard

        # Extensions from user configuration
      ]
      ++ cfg.extensions.packages;
  };
}
