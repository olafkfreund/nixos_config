{
  inputs,
  lib,
  pkgs ? {},
  ...
}: {
  # Common configuration for all users
  home.username = "olafkfreund";
  home.homeDirectory = "/home/olafkfreund";
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
}
