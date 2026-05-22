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
          "allowlockedremotedesktop@kamens.us"
          "claude-code-usage@haletran.com"
          "otp-keys@osmank3.net"
          "rudra@narkagni"
          "spotify-controller@narkagni"
          "accent-directories@taiwbi.com"
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

        # Manually-packaged extensions (extensions.gnome.org pinned ZIPs,
        # see pkgs/gnome-ext-*). Not in nixpkgs.
        gnome-ext-allow-locked-remote-desktop
        gnome-ext-claude-code-usage
        gnome-ext-otp-keys
        gnome-ext-rudra
        gnome-ext-spotify-controller
        gnome-ext-accent-directories

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
