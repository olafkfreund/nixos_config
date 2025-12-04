{ inputs
, pkgs ? { }
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
    stateVersion = "24.11";

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

  programs.home-manager.enable = true;

  # Stylix configuration (Home Manager level)
  stylix.enableReleaseChecks = false; # Disable version mismatch warnings between Stylix and Home Manager

  # Set default Nix colorscheme
  colorScheme = inputs.nix-colors.colorSchemes.gruvbox-dark-medium;

  # Common programs for all users
  programs = {
    # Enable direnv for development environments
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
