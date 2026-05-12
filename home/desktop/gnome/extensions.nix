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
        # UUIDs verified against gnomeExtensions.<name>.passthru.extensionUuid.
        # Each UUID must have a matching package in home.packages below or in
        # cfg.extensions.packages (per-profile). Adding a UUID without its
        # package makes gnome-shell silently skip it on session start.
        enabled-extensions = [
          "user-theme@gnome-shell-extensions.gcampax.github.com"
          "dash-to-dock@micxgx.gmail.com"
          "appindicatorsupport@rgcjonas.gmail.com"
          "auto-accent-colour@Wartybix"
          "auto-move-windows@gnome-shell-extensions.gcampax.github.com"
          "BringOutSubmenuOfPowerOffLogoutButton@pratap.fastmail.fm"
          "blur-my-shell@aunetx"
          "top-panel-logo@jmpegi.github.com"
          "workspace-indicator@gnome-shell-extensions.gcampax.github.com"
          "emoji-copy@felipeftn"
          "windowsNavigator@gnome-shell-extensions.gcampax.github.com"
          "caffeine@patapon.info"
          "clipboard-indicator@tudmotu.com"
          "tailscale-status@maxgallup.github.com"
          "Bluetooth-Battery-Meter@maniacx.github.com"
          "dim-background-windows@stephane-13.github.com"
          "aurora-shell@luminusos.github.io"
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

      # Aurora Shell — 10 quality-of-life modules bundled behind one
      # extension UUID (aurora-shell@luminusos.github.io). All modules
      # ON except `module-dock`, which would conflict with `dash-to-dock`
      # configured above. Re-enable module-dock only if you also disable
      # dash-to-dock in this same file.
      "org/gnome/shell/extensions/aurora-shell" = {
        module-no-overview = true;
        module-pip-on-top = true;
        module-theme-changer = true;
        module-dock = false;
        module-volume-mixer = true;
        module-xwayland-indicator = true;
        module-privacy = true;
        privacy-dnd-on-share = true;
        module-icon-weave = true;
        module-app-search-tooltip = true;
        module-auto-theme-switcher = true;
      };
    };

    # Note: Custom keybindings are defined in keybindings.nix to avoid conflicts

    # Install every extension whose UUID is in enabled-extensions above.
    # Profile-specific extras live in cfg.extensions.packages (see
    # Users/<user>/profile.nix).
    home.packages = with pkgs;
      [
        gnomeExtensions.user-themes
        gnomeExtensions.dash-to-dock
        gnomeExtensions.appindicator
        gnomeExtensions.auto-accent-colour
        gnomeExtensions.auto-move-windows
        gnomeExtensions.bring-out-submenu-of-power-offlogout-button
        gnomeExtensions.blur-my-shell
        gnomeExtensions.top-panel-logo
        gnomeExtensions.workspace-indicator
        gnomeExtensions.emoji-copy
        gnomeExtensions.windownavigator
        gnomeExtensions.caffeine
        gnomeExtensions.clipboard-indicator
        gnomeExtensions.tailscale-status
        gnomeExtensions.bluetooth-battery-meter
        gnomeExtensions.dim-background-windows
        aurora-shell

        # Helpers used by various extensions at runtime.
        lm_sensors
        curl
        jq
        xclip
        wl-clipboard
      ]
      ++ cfg.extensions.packages;
  };
}
