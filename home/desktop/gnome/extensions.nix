{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
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
          "dash-to-dock@micxgx.gmail.com"
          "appindicatorsupport@rgcjonas.gmail.com"
          "auto-accent-colour@Wartybix"
          "auto-move-windows@gnome-shell-extensions.gcampax.github.com"
          "bring-out-submenu-of-power-offlogout-button@gnome-shell-extensions.gcampax.github.com"
          "blur-my-shell@aunetx"
          "top-panel-logo@jmpegi.github.com"
          "workspace-indicator@gnome-shell-extensions.gcampax.github.com"
          "emoji-copy@felipeftn"
          "Gnofi@aylur"
          "windowsNavigator@gnome-shell-extensions.gcampax.github.com"
          "caffeine@patapon.info"
          "clipboard-indicator@tudmotu.com"
          "panel-osd@berend.de.schouwer.gmail.com"
          "tailscale-status@maxgallup.github.com"
          "user-themes@gnome-shell-extensions.gcampax.github.com"
          "bluetooth-battery@michalw.github.com"
          "BringOutSubmenuOfPowerOffLogoutButton@pratap.fastmail.fm"
        ];
      };

      # User Themes extension configuration
      # Note: Disabled until Gruvbox Shell theme is properly installed
      # "org/gnome/shell/extensions/user-theme" = {
      #   name = mkDefault (
      #     if cfg.theme.enable
      #     then "Gruvbox-Dark-BL"
      #     else "Adwaita"
      #   );
      # };

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
        # gnomeExtensions.ascii-emoji
        gnomeExtensions.dim-background-windows
        gnomeExtensions.just-perfection
        # gnomeExtensions.paperwm
        gnomeExtensions.tailscale-status
        gnomeExtensions.auto-accent-colour
        gnomeExtensions.auto-move-windows
        gnomeExtensions.bring-out-submenu-of-power-offlogout-button

        # Extension-specific packages that might be needed
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
