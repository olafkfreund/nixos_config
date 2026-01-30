{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.gtk-cosmic-fix;

  # Script to patch COSMIC's dark.css with Gruvbox import and button fixes
  patchScript = pkgs.writeShellScript "patch-cosmic-gtk" ''
        DARK_CSS="$HOME/.config/gtk-4.0/cosmic/dark.css"
        GRUVBOX_CSS="$HOME/.local/share/themes/Gruvbox-Material-Dark/gtk-4.0/gtk.css"

        # Only patch if files exist
        if [ ! -f "$DARK_CSS" ] || [ ! -f "$GRUVBOX_CSS" ]; then
          echo "Required files not found, skipping"
          exit 0
        fi

        # Check if already patched (check for both import and button fix)
        if grep -q "@import.*Gruvbox-Material-Dark" "$DARK_CSS" 2>/dev/null && \
           grep -q "Window control button sizing fix" "$DARK_CSS" 2>/dev/null; then
          echo "Already patched, skipping"
          exit 0
        fi

        echo "Patching COSMIC GTK CSS with Gruvbox theme..."

        # Create backup
        cp "$DARK_CSS" "$DARK_CSS.backup"

        # Build the patched file: import + original + button fixes
        {
          echo '@import url("file:///home/${cfg.username}/.local/share/themes/Gruvbox-Material-Dark/gtk-4.0/gtk.css");'
          echo ""
          echo "/* COSMIC color overrides below */"
          cat "$DARK_CSS.backup"
          echo ""
          cat << 'BUTTONFIX'
    /* Window control button sizing fix for COSMIC */
    windowcontrols button {
      min-height: 24px;
      min-width: 24px;
      max-height: 24px;
      max-width: 24px;
      padding: 4px;
      margin: 2px;
      border-radius: 50%;
    }

    windowcontrols button.close,
    windowcontrols button.maximize,
    windowcontrols button.minimize {
      min-height: 24px;
      min-width: 24px;
      max-height: 24px;
      max-width: 24px;
      padding: 4px;
    }

    headerbar windowcontrols button,
    .titlebar windowcontrols button {
      min-height: 24px;
      min-width: 24px;
      max-height: 24px;
      max-width: 24px;
      padding: 4px;
      margin: 2px;
    }

    /* Ensure icons inside buttons don't overflow */
    windowcontrols button image,
    windowcontrols button > image {
      min-width: 16px;
      min-height: 16px;
      max-width: 16px;
      max-height: 16px;
    }
    BUTTONFIX
        } > "$DARK_CSS"

        echo "GTK CSS patched successfully with theme import and button fixes"
  '';
in
{
  options.gtk-cosmic-fix = {
    enable = mkEnableOption "COSMIC GTK theme fix (merges Gruvbox with COSMIC colors)";

    username = mkOption {
      type = types.str;
      default = "olafkfreund";
      description = "Username for path resolution";
    };
  };

  config = mkIf cfg.enable {
    # Systemd path unit to watch for changes to dark.css
    systemd.user.paths.cosmic-gtk-watcher = {
      Unit = {
        Description = "Watch COSMIC GTK CSS for changes";
      };
      Path = {
        PathChanged = "%h/.config/gtk-4.0/cosmic/dark.css";
        Unit = "cosmic-gtk-patcher.service";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # Systemd service to patch the CSS
    systemd.user.services.cosmic-gtk-patcher = {
      Unit = {
        Description = "Patch COSMIC GTK CSS with Gruvbox theme";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${patchScript}";
        # Small delay to ensure COSMIC finished writing
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 1";
      };
    };

    # Also run on login to ensure it's patched
    systemd.user.services.cosmic-gtk-patcher-init = {
      Unit = {
        Description = "Initial patch of COSMIC GTK CSS with Gruvbox theme";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${patchScript}";
        # Delay to let COSMIC initialize
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 3";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
