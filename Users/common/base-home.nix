{
  inputs,
  lib,
  pkgs ? {},
  username ? "olafkfreund", # Default fallback
  ...
}: {
  # Common configuration for all users
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  home = {
    sessionVariables = {
      XDG_CACHE_HOME = "\${HOME}/.cache";
      XDG_CONFIG_HOME = "\${HOME}/.config";
      XDG_BIN_HOME = "\${HOME}/.local/bin";
      XDG_DATA_HOME = "\${HOME}/.local/share";
    };
  };

  home.stateVersion = "24.11";
  programs.home-manager.enable = true;

  # Set default Nix colorscheme
  colorScheme = inputs.nix-colors.colorSchemes.gruvbox-dark-medium;

  # Common packages for all users
  home.packages = with pkgs; [
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

  # Common programs for all users
  programs = {
    # Enable direnv for development environments
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
