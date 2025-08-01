{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    # Import common modules
    ../common/default.nix

    # Host-specific imports
    ../../home/default.nix
    ../../home/games/steam.nix
    ../../home/desktop/sway/default.nix
    ../../home/desktop/sway/swayosd.nix
    ../../hosts/p620/nixos/env.nix
    ./private.nix
  ];

  # Use the new features system instead of multiple lib.mkForce calls
  features = {
    terminals = {
      enable = true;
      alacritty = true;
      foot = true;
      wezterm = true;
      kitty = true;
      ghostty = true;
    };

    editors = {
      enable = true;
      cursor = true;
      neovim = true;
      vscode = true;
      zed = true;
      windsurf = true;
    };

    browsers = {
      enable = true;
      chrome = true;
      firefox = true;
      edge = false;
      brave = false;
      opera = false;
    };

    desktop = {
      enable = true;
      sway = false;
      dunst = false;
      swaync = true;
      zathura = true;
      rofi = true;
      obsidian = true;
      swaylock = true;
      flameshot = true;
      kooha = true;
      remotedesktop = true;
      walker = true;

      # Communication and media
      obs = true;
      evince = true;
      kdeconnect = true;
      slack = true;
    };

    cli = {
      enable = true;
      bat = true;
      direnv = true;
      fzf = true;
      lf = true;
      starship = true;
      yazi = true;
      zoxide = true;
      gh = true;
      markdown = true;
    };

    multiplexers = {
      enable = true;
      tmux = true;
      zellij = true;
    };

    gaming = {
      enable = true;
      steam = true;
    };
  };

  home.packages = [
    # pkgs.customPkgs.rofi-blocks
    # pkgs.msty
    # pkgs.aider-chat-env
  ];

  # Optional: Add additional packages to the Windsurf environment
  editor.windsurf.extraPackages = with pkgs; [
    nixpkgs-fmt
    nil
  ];

  # Optional: Configure Windsurf settings
  editor.windsurf.settings = {
    theme = "gruvbox";
  };

  programs.chromium.commandLineArgs = lib.mkForce [
    "--enable-features=UseOzonePlatform,VaapiVideoDecoder,VaapiVideoEncoder,CanvasOopRasterization"
    "--ozone-platform=wayland"
    "--enable-gpu-rasterization"
    "--enable-zero-copy"
    "--ignore-gpu-blocklist"
    "--enable-hardware-overlays"
  ];
}
