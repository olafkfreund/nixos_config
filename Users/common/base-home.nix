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
  programs.git.signing.format = null;

  # We intentionally chase nixos-unstable for nixpkgs; HM/Stylix master often
  # advance to the next release cycle before nixpkgs unstable does, producing
  # "mismatched versions" nags at HM profile evaluation. The system-level
  # stylix.enableReleaseChecks in modules/desktop/stylix-theme.nix only silences
  # the NixOS-level check; the HM-profile check needs its own opt-out here.
  home.enableNixpkgsReleaseCheck = false;
  stylix.enableReleaseChecks = false;

  programs.home-manager.enable = true;

  # Stylix theming targets (Home Manager level). GTK is enabled fleet-wide
  # because COSMIC's GTK theme sync is off on every host; cosmic-comp does not
  # clobber ~/.config/gtk-{3,4}.0/gtk.css at runtime.
  stylix.targets = {
    wezterm.enable = true;
    ghostty.enable = true;
    gtk.enable = true;
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
