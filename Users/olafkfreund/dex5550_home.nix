{
  inputs,
  lib,
  username,
  ...
}: {
  imports = [
    inputs.nix-colors.homeManagerModules.default
    inputs.ags.homeManagerModules.default
    inputs.spicetify-nix.homeManagerModules.default

    ../../home/desktop.nix
    ../../hosts/dex5550/nixos/hypr_override.nix
    ../../home/desktop/sway/default.nix
    ../../home/desktop/sway/swayosd.nix
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

  programs.obs.enable = lib.mkForce false;
  programs.kdeconnect.enable = lib.mkForce false;
  programs.slack.enable = lib.mkForce false;
  # Terminals
  alacritty.enable = lib.mkForce false;
  foot.enable = lib.mkForce true;
  wezterm.enable = lib.mkForce false;
  kitty.enable = lib.mkForce false;

  # Wayland apps
  desktop.zathura.enable = lib.mkForce true;
  desktop.sway.enable = lib.mkForce true;
  desktop.dunst.enable = lib.mkForce false;
  desktop.rofi.enable = lib.mkForce true;
  swaylock.enable = lib.mkForce false;
  desktop.screenshots.flameshot.enable = lib.mkForce true;
  desktop.screenshots.kooha.enable = lib.mkForce true;
  desktop.remotedesktop.enable = lib.mkForce true;

  # Browsers
  browsers.chrome.enable = lib.mkForce true;
  browsers.firefox.enable = lib.mkForce true;
  browsers.edge.enable = lib.mkForce false;
  browsers.brave.enable = lib.mkForce false;
  browsers.opera.enable = lib.mkForce false;

  # Editors
  editor.cursor.enable = lib.mkForce false;
  editor.neovim.enable = lib.mkForce true;
  editor.vscode.enable = lib.mkForce false;

  # Shell tools
  cli.bat.enable = lib.mkForce true;
  cli.direnv.enable = true;
  cli.fzf.enable = true;
  cli.lf.enable = lib.mkForce true;
  cli.starship.enable = lib.mkForce true;
  cli.yazi.enable = lib.mkForce true;
  cli.zoxide.enable = lib.mkForce true;
  cli.versioncontrol.gh.enable = lib.mkForce true;
  cli.markdown.enable = lib.mkForce true;

  # Multiplexers
  multiplexer.tmux.enable = lib.mkForce true;
  multiplexer.zellij.enable = lib.mkForce true;

  wayland.windowManager.sway = {
    extraConfig = ''
      output HEADLESS-1 pos 0 0 res 3840x2160
    '';
  };
}
