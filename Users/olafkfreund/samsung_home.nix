{ lib
, pkgs
, config
, ...
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

  # Fix Stylix Firefox profile warnings
  stylix.targets.firefox.profileNames = [ "default" ];

  # Enable Walker launcher when feature flag is set
  desktop.walker.enable = config.features.desktop.walker;

  # GNOME desktop environment (optional - can be enabled/disabled)
  desktop.gnome = {
    enable = true; # Set to true to enable GNOME
    theme = {
      enable = true;
      variant = "dark";
    };
    extensions = {
      enable = true;
      packages = with pkgs.gnomeExtensions; [
        # Laptop-optimized extensions
        dash-to-dock
        appindicator
        battery-health-charging # Battery management
        caffeine # Prevent sleep
        clipboard-indicator
      ];
    };
    apps = {
      enable = true;
      packages = with pkgs; [
        # Essential GNOME apps for laptop
        gnome-power-manager
        gnome-system-monitor
      ];
    };
    keybindings.enable = true;
  };

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
      walker = true; # Re-enabled with Stylix integration

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
