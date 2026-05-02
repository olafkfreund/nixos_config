{ pkgs ? { }
, lib
, username ? "olafkfreund"
, # Default fallback
  ...
}: {
  # Common configuration for all users
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    sessionPath = [
      "$HOME/.local/bin"
    ];
    sessionVariables = {
      XDG_CACHE_HOME = "\${HOME}/.cache";
      XDG_CONFIG_HOME = "\${HOME}/.config";
      XDG_BIN_HOME = "\${HOME}/.local/bin";
      XDG_DATA_HOME = "\${HOME}/.local/share";

      # Obsidian MCP server vault path
      OBSIDIAN_VAULT_PATH = "\${HOME}/Documents/Caliti";
    };
    stateVersion = "26.05";

    # One-time cleanup: remove dummy cosmic-osd left by the now-removed
    # cosmic-osd-blocker workaround (fixed in COSMIC 1.0, PR #296).
    # Safe to keep permanently - idempotent, does nothing if file is absent.
    activation.removeCosmicOsdDummy = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -f "$HOME/.local/bin/cosmic-osd" ]; then
        $DRY_RUN_CMD rm "$HOME/.local/bin/cosmic-osd"
        echo "Removed leftover dummy cosmic-osd from ~/.local/bin/"
      fi
    '';

    # Common packages for all users
    packages = with pkgs; [
      # Essential utilities
      coreutils
      findutils
      which
      file

      # Network tools
      wget
      curl

      # Text processing
      less
      nano

      # Archive tools
      unzip
      zip
      gnutar
      gzip
    ];
  };

  # Adopt new Home Manager defaults (silence deprecation warnings)
  gtk.gtk4.theme = null;
  programs.git.signing.format = null;

  programs.home-manager.enable = true;

  # Stylix theming targets (Home Manager level).
  # `enableReleaseChecks = false` is set once in modules/desktop/stylix-theme.nix
  # at the system level — no need to repeat it here.
  #
  # COSMIC firewall: gtk.enable stays false so HM never writes
  # ~/.config/gtk-{3,4}.0/gtk.css. cosmic-comp owns that path at runtime
  # (symlinks gtk.css to its own ~/.config/gtk-4.0/cosmic/dark.css). GNOME
  # themes correctly without it via Stylix's targets.gnome (gsettings + theme
  # package).
  stylix.targets = {
    wezterm.enable = true;
    ghostty.enable = true;
    gtk.enable = false; # COSMIC firewall — see comment above
    qt.enable = false; # Qt theming handled by home/desktop/theme/qt.nix
  };

  # Common programs for all users
  programs = {
    # Enable direnv for development environments
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
