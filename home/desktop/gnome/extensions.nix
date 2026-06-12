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
    # GNOME Shell extensions configuration via dconf.
    #
    # Snapshot policy: the enabled-extensions list captures the exact set of
    # extensions ACTIVE on p620 today (2026-05). Anything that was declared
    # but in state INITIALIZED/INACTIVE was dropped — see git log for the
    # cull. aurora-shell is included here without a matching nix package
    # because the binary lives in ~/.local/share/gnome-shell/extensions/
    # from a manual install; including the UUID prevents this dconf block
    # from stripping it on activation. razer doesn't have the binary, so
    # GNOME will silently skip aurora-shell there.
    dconf.settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false;
        # Restore the logout entry in the system menu on single-user GNOME 50+.
        # GNOME 50 hid logout by default on single-user systems ("nothing to log
        # out to"), but it's still useful for forcing a fresh shell session
        # after extension changes / login-time tweaks. Re-enabling here makes
        # the entry visible in the power menu next to Restart / Shut Down.
        always-show-log-out = true;
        # UUIDs verified against gnomeExtensions.<name>.passthru.extensionUuid
        # (for nixpkgs entries) or against metadata.json of the manual zips
        # we re-package in pkgs/gnome-ext-*. Each UUID must have either a
        # matching package in home.packages below, or be an explicit
        # user-managed drift entry (aurora-shell — see policy comment above).
        enabled-extensions = [
          "user-theme@gnome-shell-extensions.gcampax.github.com"
          "dash-to-dock@micxgx.gmail.com"
          "appindicatorsupport@rgcjonas.gmail.com"
          "caffeine@patapon.info"
          "tailscale-status@maxgallup.github.com"
          "Bluetooth-Battery-Meter@maniacx.github.com"
          "dim-background-windows@stephane-13.github.com"
          "yetanotherradio@io.github.buddysirjava"
          "allowlockedremotedesktop@kamens.us"
          # Claude Code Usage Monitor — dvdstelt's variant (the one actually
          # installed). Replaces the older claude-code-usage@haletran.com.
          "claude-usage@dvdstelt.github.io"
          "otp-keys@osmank3.net"
          # Added 2026-06 from the user's installed set:
          "docker-manager@omerfarukgungor"
          "dynamic-calendar-and-clocks-icons-reborn@thecalamityjoe87.github.com"
          "notification-configurator@exposedcat"
          "screencast.extra.feature@wissle.me"
          "shotzy@SamkitJain660.github.io"
          "slider-percentages@imdarktom"
          "rudra@narkagni"
          "spotify-controller@narkagni"
          "accent-directories@taiwbi.com"
          "forge@jmmaranan.com"
          # Clipboard Indicator — panel-bar clipboard history. Paired with
          # the wl-paste --watch user service (home/desktop/gnome/wl-paste-watch.nix)
          # which actually drains wl_data_source ownership so wl-copy
          # zombies stop piling up in the dock. The extension itself
          # only provides the UI; without the watcher daemon the
          # dock-icon problem persists.
          "clipboard-indicator@tudmotu.com"
          # User-managed drift — see policy comment above.
          "aurora-shell@luminusos.github.io"
        ];
      };

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

      # Caffeine configuration
      "org/gnome/shell/extensions/caffeine" = {
        enable-fullscreen = true;
        restore-state = true;
        show-indicator = true;
        show-notification = false;
      };

      # Dim Background Windows configuration
      "org/gnome/shell/extensions/dim-background-windows" = {
        dim-background = true;
        dimming-enabled = true;
        toogle-shortcut = "<Super>g";
      };
    };

    # Note: Custom keybindings are defined in keybindings.nix to avoid conflicts

    # Install every extension whose UUID is in enabled-extensions above.
    # Profile-specific extras live in cfg.extensions.packages (see
    # Users/<user>/profile.nix).
    home.packages = with pkgs;
      [
        # nixpkgs entries
        gnomeExtensions.user-themes
        gnomeExtensions.dash-to-dock
        gnomeExtensions.appindicator
        gnomeExtensions.caffeine
        gnomeExtensions.tailscale-status
        gnomeExtensions.bluetooth-battery-meter
        gnomeExtensions.dim-background-windows
        gnomeExtensions.yet-another-radio
        gnomeExtensions.clipboard-indicator
        gnomeExtensions.notification-configurator
        gnomeExtensions.shotzy
        gnomeExtensions.screencast-extra-feature

        # Manually-packaged extensions (extensions.gnome.org pinned ZIPs,
        # see pkgs/gnome-ext-*). Not in nixpkgs.
        gnome-ext-allow-locked-remote-desktop
        gnome-ext-claude-usage-dvdstelt
        gnome-ext-docker-manager
        gnome-ext-slider-percentages
        gnome-ext-dynamic-calendar-reborn
        gnome-ext-otp-keys
        gnome-ext-rudra
        gnome-ext-spotify-controller
        gnome-ext-accent-directories
        gnome-ext-forge

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
