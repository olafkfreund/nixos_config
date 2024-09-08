{inputs, ...}: {
  imports = [
    inputs.ags.homeManagerModules.default
    inputs.spicetify-nix.homeManagerModules.default
    inputs.nix-colors.homeManagerModules.default

    ../../home/servers.nix
    ./private.nix
  ];

  colorScheme = inputs.nix-colors.colorSchemes.gruvbox-dark-medium;

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
}
