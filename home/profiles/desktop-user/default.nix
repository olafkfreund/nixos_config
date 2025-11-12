# Desktop User Profile - Full GUI configuration for desktop environments
# Used by: P620, workstation environments, full desktop setups
{ lib
, pkgs
, ...
}: {
  imports = [
    # Import full home manager module suite
    ../../default.nix # Base home manager configuration
    ../../desktop/sway/default.nix # Window manager
    ../../desktop/sway/swayosd.nix # System OSD
    ../../desktop/gnome # GNOME desktop environment (optional)
    ../../games/steam.nix # Gaming support
  ];

  # Desktop user feature configuration - full GUI environment
  features = {
    terminals = {
      enable = true; # Full terminal suite for different use cases
      alacritty = true;
      foot = true;
      wezterm = true;
      kitty = true;
      ghostty = true;
    };

    editors = {
      enable = true; # Full editor suite for various tasks
      cursor = true; # AI-powered editing
      neovim = true; # Terminal editor
      vscode = true; # Primary GUI editor
      zed = true; # Modern editor
      windsurf = true; # Web-based editor
    };

    browsers = {
      enable = true; # Full browser suite
      chrome = true; # Primary browser
      firefox = true; # Alternative browser
      edge = false; # Optional
      brave = false; # Privacy-focused option
      opera = false; # Alternative option
    };

    desktop = {
      enable = true; # Full desktop environment
      sway = true; # Window manager
      zathura = true; # PDF viewer
      obsidian = true; # Note-taking and knowledge management
      flameshot = true; # Screenshot tool
      kooha = true; # Screen recording
      remotedesktop = true; # Remote desktop access
      quickshell = lib.mkDefault false; # Advanced desktop shell (can be enabled per-host)

      # Communication and media
      obs = true; # Content creation
      evince = true; # PDF viewer
      kdeconnect = true; # Mobile integration
      slack = true; # Communication
    };

    cli = {
      enable = true; # CLI tools for power users
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
      enable = true; # Session management
      tmux = true;
      zellij = false; # Prefer tmux for desktop use
    };

    gaming = {
      enable = true; # Full gaming support
      steam = true;
    };

    development = {
      enable = true; # Basic development support
      languages = true; # Language support
      workflow = true; # Development workflow
      productivity = true; # Productivity tools
    };
  };

  # Desktop user specific packages
  home.packages = with pkgs; [
    # Media and graphics
    gimp
    inkscape
    blender
    vlc
    mpv

    # Office and productivity
    libreoffice-bin # Disabled: large build, use onlyoffice or online alternatives
    thunderbird

    # Communication
    discord
    telegram-desktop
    signal-desktop

    # File management
    nautilus
    thunar

    # System utilities with GUI
    gnome.gnome-system-monitor
    gnome.file-roller

    # Development utilities
    git
    gh

    # Network utilities
    wireshark

    # Archive tools
    unzip
    p7zip

    # Multimedia tools
    audacity
    kdenlive

    # Fonts and themes
    font-awesome
    noto-fonts
    noto-fonts-color-emoji

    # System information
    neofetch
    htop
    btop

    # Text processing
    pandoc

    # Password management
    keepassxc

    # Note-taking and documentation
    obsidian

    # Web development
    httpie

    # Image optimization
    imagemagick
    optipng

    # Screen capture
    peek

    # Color picker
    grim
    slurp

    # Clipboard manager
    wl-clipboard

    # Application launcher helpers
    fuzzel

    # System monitoring
    iotop

    # Network tools
    nmap

    # File synchronization
    rsync
  ];

  # Desktop-specific program configurations
  programs.firefox = {
    enable = true;
    profiles.default = {
      settings = {
        # Desktop-optimized Firefox settings
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "media.ffmpeg.vaapi.enabled" = true;
        "dom.security.https_only_mode" = true;
        "privacy.trackingprotection.enabled" = true;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
      };
    };
  };

  # Chrome/Chromium configuration for desktop use
  programs.chromium = {
    enable = true;
    package = lib.mkDefault pkgs.google-chrome;
    commandLineArgs = [
      # Wayland support
      "--enable-features=UseOzonePlatform,WaylandWindowDecorations"
      "--ozone-platform=wayland"

      # Hardware acceleration
      "--enable-gpu-rasterization"
      "--enable-zero-copy"
      "--ignore-gpu-blocklist"

      # Performance optimizations
      "--enable-accelerated-2d-canvas"
      "--enable-accelerated-video-decode"

      # Security and stability
      "--enable-quic"
      "--enable-tcp-fast-open"
    ];
  };
}
