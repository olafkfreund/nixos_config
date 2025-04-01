{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    inputs.nix-colors.homeManagerModules.default
    inputs.ags.homeManagerModules.default
    inputs.spicetify-nix.homeManagerModules.default
    inputs.nixcord.homeManagerModules.nixcord

    ../../home/default.nix
    ../../home/games/steam.nix
    ../../home/desktop/sway/default.nix
    ../../home/desktop/sway/swayosd.nix
    # ../../home/chat/nixcord.nix
    ../../hosts/p620/nixos/env.nix
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

  home.packages = with pkgs; [
    # msty
    # aider-chat-env
  ];
  programs.home-manager.enable = true;

  programs.obs.enable = lib.mkForce true;
  programs.evince.enable = lib.mkForce true;
  programs.kdeconnect.enable = lib.mkForce true;
  programs.slack.enable = lib.mkForce true;
  # Terminals
  alacritty.enable = lib.mkForce true;
  foot.enable = lib.mkForce true;
  wezterm.enable = lib.mkForce true;
  kitty.enable = lib.mkForce true;

  # Wayland apps
  # desktop.sway.enable = lib.mkForce false;
  desktop.zathura.enable = lib.mkForce true;
  desktop.dunst.enable = lib.mkForce false;
  desktop.swaync.enable = lib.mkForce true;
  desktop.sway.enable = lib.mkForce true;
  desktop.rofi.enable = lib.mkForce true;
  swaylock.enable = lib.mkForce true;
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
  editor.cursor.enable = lib.mkForce true;
  editor.neovim.enable = lib.mkForce true;
  editor.vscode.enable = lib.mkForce true;

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
  programs.chromium.commandLineArgs = lib.mkForce [
    "--enable-features=UseOzonePlatform"
    "--ozone-platform=wayland"
    # "--use-gl=egl"
    # "--enable-unsafe-webgpu"
    # "--ignore-gpu-blocklist"
    # "--enable-gpu-rasterization"
    # "--use-gl=angel"
    # "--use-angle=vulkan"
    # "--enable-features=Vulkan,VulkanFromANGLE,DefaultANGLEVulkan,VaapiIgnoreDriverChecks,VaapiVideoDecoder,UseMultiPlaneFormatForHardwareVideo,VaapiVideoEncoder"
    # "--enable-features=enableVulkan"
  ];
}
