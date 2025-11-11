{
  lib,
  pkgs,
  config,
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

  # Fix Stylix Firefox profile warnings
  stylix.targets.firefox.profileNames = ["default"];

  # Enable Walker launcher when feature flag is set
  desktop.walker.enable = config.features.desktop.walker;

  # Terminal app desktop entries
  programs.k9s.desktopEntry.enable = lib.mkForce true;
  programs.claude-code.desktopEntry.enable = lib.mkForce true;
  programs.neovim.desktopEntry.enable = lib.mkForce true;

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
        # Add popular extensions for workstation use
        dash-to-dock
        appindicator
        vitals
        blur-my-shell
      ];
    };
    apps = {
      enable = true;
      packages = with pkgs; [
        # Add additional GNOME apps as needed
        gnome-tweaks
        dconf-editor
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

  # GitLab development configuration for P620
  development.gitlab = {
    enable = true;
    runner.enable = true;
    fluxcd.enable = true;
    ciLocal.enable = true;
  };

  # Override desktop features for P620 (add to existing desktop config)
  features.desktop.quickshell = true;

  # Enable Proton applications suite for P620
  programs.proton = {
    enable = true;
    vpn.enable = true;
    pass.enable = true;
    mail.enable = true;
    authenticator.enable = true;
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

  # P620 Chrome configuration - Modern flags for AMD GPU systems
  programs.chromium = {
    package = lib.mkForce pkgs.google-chrome;
    commandLineArgs = lib.mkForce [
      # Modern Wayland support
      "--enable-features=UseOzonePlatform,WaylandWindowDecorations,WebRTCPipeWireCapturer"
      "--ozone-platform=wayland"
      "--disable-features=VizDisplayCompositor"

      # Modern AMD GPU acceleration
      "--use-gl=desktop"
      "--enable-gpu-rasterization"
      "--enable-zero-copy"
      "--ignore-gpu-blocklist"
      "--disable-gpu-driver-bug-workarounds"

      # Hardware acceleration for AMD
      "--enable-accelerated-2d-canvas"
      "--enable-accelerated-video-decode"
      "--use-vulkan"

      # Network and stability improvements
      "--enable-quic"
      "--enable-tcp-fast-open"
      "--aggressive-cache-discard"

      # Process and memory optimization
      "--process-per-site"
      "--max_old_space_size=4096"
      "--memory-pressure-off"

      # Fix zygote/sandbox error
      "--no-zygote"
      "--no-sandbox"
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
