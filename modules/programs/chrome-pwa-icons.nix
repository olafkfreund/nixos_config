# Chrome PWA Icon Sync
#
# Chromium-based browsers install PWAs as .desktop files referencing icons by
# bare name (Icon=chrome-<id>-Profile_<n>) but store the actual PNG files only inside
# ~/.config/google-chrome/Profile <n>/Web Applications/Manifest Resources/<id>/Icons/.
# That path is not on any XDG icon search path, so launchers (COSMIC, GNOME)
# fall back to a generic placeholder.
#
# This module installs a per-user oneshot service + timer that symlinks every
# Chrome-downloaded PWA icon into ~/.local/share/icons/hicolor/<size>x<size>/apps/
# and refreshes the GTK icon cache. Idempotent, fast, and reversible.
#
# Tracked in issue #397.
{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.modules.programs.chrome-pwa-icons;

  syncScript = pkgs.writeShellApplication {
    name = "chrome-pwa-icon-sync";

    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gtk3 # provides gtk-update-icon-cache
    ];

    text = ''
      set -euo pipefail

      home_dir="''${HOME:-/home/${cfg.user}}"
      hicolor="$home_dir/.local/share/icons/hicolor"
      apps_dir="$home_dir/.local/share/applications"

      # 1. Prune any dangling chrome-*-Profile_*.png symlinks from prior runs.
      #    -xtype l matches symlinks whose target no longer exists.
      if [[ -d "$hicolor" ]]; then
        find "$hicolor" -path '*/apps/chrome-*-Profile_*.png' -xtype l -delete 2>/dev/null || true
      fi

      linked=0
      skipped=0

      # 2. Walk every chrome-*-Profile_*.desktop entry and re-link its icons.
      shopt -s nullglob
      for desktop in "$apps_dir"/chrome-*-Profile_*.desktop; do
        [[ -f "$desktop" ]] || continue
        base=$(basename "$desktop" .desktop)
        rest=''${base#chrome-}
        app_id=''${rest%-Profile_*}
        profile_num=''${rest##*-Profile_}

        # Map profile_num to Chrome's profile directory name. "Default" is
        # treated as profile_num=Default; numeric ids map to "Profile <n>".
        if [[ "$profile_num" == "Default" ]]; then
          src_dir="$home_dir/.config/google-chrome/Default/Web Applications/Manifest Resources/$app_id/Icons"
        else
          src_dir="$home_dir/.config/google-chrome/Profile $profile_num/Web Applications/Manifest Resources/$app_id/Icons"
        fi

        if [[ ! -d "$src_dir" ]]; then
          skipped=$((skipped + 1))
          continue
        fi

        for png in "$src_dir"/*.png; do
          [[ -f "$png" ]] || continue
          size=$(basename "$png" .png)
          # Only accept numeric sizes; skip anything else (e.g. "maskable").
          [[ "$size" =~ ^[0-9]+$ ]] || continue
          dest_dir="$hicolor/''${size}x''${size}/apps"
          mkdir -p "$dest_dir"
          ln -sf "$png" "$dest_dir/''${base}.png"
          linked=$((linked + 1))
        done
      done

      # 3. Refresh GTK icon cache so launchers pick up new entries.
      if [[ -d "$hicolor" ]]; then
        gtk-update-icon-cache --quiet --force "$hicolor" 2>/dev/null || true
      fi

      echo "chrome-pwa-icon-sync: linked=$linked skipped=$skipped"
    '';
  };
in
{
  options.modules.programs.chrome-pwa-icons = {
    enable = lib.mkEnableOption "Chrome PWA icon sync into the XDG hicolor tree";

    user = lib.mkOption {
      type = lib.types.str;
      example = "alice";
      description = ''
        User whose Chrome profiles will be scanned and whose
        ~/.local/share/icons/hicolor tree will receive the symlinks.
      '';
    };

    syncIntervalMinutes = lib.mkOption {
      type = lib.types.ints.between 0 1440;
      default = 15;
      description = ''
        How often the timer fires while the user is logged in. Set to 0 to
        disable the timer (the service still runs once at login).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.user != "";
        message = "modules.programs.chrome-pwa-icons.user must be set";
      }
    ];

    systemd.user.services.chrome-pwa-icon-sync = {
      description = "Sync Chrome PWA icons into the XDG hicolor tree";
      wantedBy = [ "default.target" ];
      after = [ "graphical-session.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe syncScript;

        # The user systemd manager already runs as cfg.user; these reduce
        # blast radius further while still allowing writes to ~/.local/share.
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictSUIDSGID = true;
      };
    };

    systemd.user.timers.chrome-pwa-icon-sync = lib.mkIf (cfg.syncIntervalMinutes > 0) {
      description = "Periodic re-sync of Chrome PWA icons";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnUnitActiveSec = "${toString cfg.syncIntervalMinutes}min";
        OnBootSec = "2min";
        Unit = "chrome-pwa-icon-sync.service";
      };
    };
  };
}
