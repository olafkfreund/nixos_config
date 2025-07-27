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
      sway = true;
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
      zellij = false;
    };

    gaming = {
      enable = true;
      steam = true;
    };

    development = {
      enable = true;
      languages = true;
      workflow = true;
      productivity = true;
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

  # P620 Chrome fix - Working configuration now applied to Google Chrome
  programs.chromium = {
    package = lib.mkForce pkgs.google-chrome;  # Switch back to Google Chrome
    commandLineArgs = lib.mkForce [
      # Wayland support
      "--enable-features=UseOzonePlatform"
      "--ozone-platform=wayland"
      "--disable-features=VizDisplayCompositor"
      
      # Graphics/GL fixes (the key that made it work)
      "--use-gl=desktop"
      "--enable-gpu-rasterization"
      "--ignore-gpu-blocklist"
      
      # Stable process model
      "--process-per-site"
      
      # Memory management
      "--max_old_space_size=4096"
      "--memory-pressure-off"
    ];
  };
  
  # Keep Firefox as backup
  programs.firefox = {
    enable = true;
    profiles.default = {
      settings = {
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "media.ffmpeg.vaapi.enabled" = true;
      };
    };
  };
}
