# Laptop User Profile - Mobile-optimized configuration with power management
# Used by: Razer, Samsung, portable systems with battery considerations
{ lib, pkgs, ... }: {
  imports = [
    # Import home manager modules optimized for mobile use
    ../../browsers/default.nix # Browser support
    ../../desktop/terminals/default.nix # Terminal options
    ../../shell/default.nix # CLI shell configuration
    ../../development/default.nix # Development tools (lightweight selection)
    ../../media/music.nix # Music for mobile entertainment
    ../../files.nix # File associations

    # Desktop modules for mobile desktop environment
    ../../desktop/sway/default.nix # Lightweight window manager
    ../../desktop/sway/swayosd.nix # System OSD for laptops
    ../../desktop/gnome # GNOME desktop environment (optional)
    ../../desktop/zathura/default.nix # Lightweight PDF viewer
    ../../desktop/obsidian/default.nix # Note-taking (can sync across devices)
    ../../desktop/flameshot/default.nix # Screenshots
    ../../desktop/kooha/default.nix # Screen recording
    ../../desktop/remotedesktop/default.nix # Remote access

    # Mobile-friendly program modules
    ../../desktop/evince/default.nix # PDF viewer
    ../../desktop/kdeconnect/default.nix # Mobile integration (essential)
    ../../desktop/slack/default.nix # Communication
  ];

  # Laptop user feature configuration - mobile-optimized
  features = {
    terminals = {
      enable = true; # Terminals optimized for battery life
      alacritty = true; # Lightweight and efficient
      foot = true; # Wayland-native, efficient
      wezterm = false; # More resource-intensive
      kitty = true; # GPU-accelerated but can be power-hungry
      ghostty = false; # Skip for battery optimization
    };

    editors = {
      enable = true; # Balanced editor selection for mobile productivity
      cursor = false; # Resource-intensive AI editor
      neovim = true; # Essential terminal editor
      vscode = true; # Primary GUI editor (essential for development)
      zed = true; # Lightweight modern editor
      windsurf = false; # Web-based, less suitable for mobile
    };

    browsers = {
      enable = true; # Limited browser selection for battery optimization
      chrome = true; # Primary browser (efficient on modern systems)
      firefox = true; # Alternative browser
      edge = false; # Skip for battery optimization
      brave = false; # Skip additional browsers
      opera = false; # Skip additional browsers
    };

    desktop = {
      enable = true; # Mobile-optimized desktop environment
      sway = true; # Efficient Wayland compositor
      zathura = true; # Lightweight PDF viewer
      obsidian = true; # Note-taking with cloud sync
      flameshot = true; # Screenshot capability
      kooha = false; # Skip screen recording to save battery
      remotedesktop = true; # Remote access capability

      # Communication optimized for mobile
      obs = false; # Skip resource-intensive recording
      evince = true; # Lightweight document viewer
      kdeconnect = true; # Essential mobile integration
      slack = true; # Communication (can be battery-optimized)
    };

    cli = {
      enable = true; # Essential CLI tools
      bat = true;
      direnv = true;
      fzf = true;
      lf = true;
      starship = true; # Enhanced prompt
      yazi = false; # Skip additional file manager for simplicity
      zoxide = true; # Smart navigation
      gh = true; # GitHub CLI
      markdown = true; # Documentation tools
    };

    multiplexers = {
      enable = true; # Session management for mobile workflows
      tmux = true;
      zellij = false; # Prefer tmux for battery efficiency
    };

    gaming = {
      enable = true; # Limited gaming for mobile
      steam = true; # Can be useful for indie games
    };

    development = {
      enable = true; # Development capabilities for mobile work
      languages = true; # Language support
      workflow = true; # Development workflow
      productivity = false; # Skip heavy productivity tools
    };
  };

  # Laptop-specific packages optimized for mobile use
  home.packages = with pkgs; [
    # Essential mobile utilities
    brightnessctl # Screen brightness control
    playerctl # Media player control
    pamixer # Audio control

    # Battery and power management
    powertop # Power consumption analysis
    acpi # Battery status

    # Network management for mobile
    networkmanager # Network connection management

    # File management
    nautilus # GUI file manager

    # Essential multimedia (lightweight)
    vlc # Media player
    mpv # Lightweight media player

    # Communication essentials
    signal-desktop # Secure messaging
    telegram-desktop # Messaging

    # Productivity (essential only)
    # libreoffice # Office suite - Disabled: large build
    thunderbird # Email client

    # Development essentials
    git
    gh

    # System utilities
    htop
    btop

    # Archive tools
    unzip
    p7zip

    # Image viewing and basic editing
    imv # Lightweight image viewer

    # PDF tools
    poppler_utils # PDF utilities

    # Text processing
    pandoc

    # Password management
    keepassxc

    # Cloud storage and sync
    nextcloud-client # File synchronization

    # Mobile-specific tools
    libnotify # Desktop notifications

    # Screen capture (lightweight)
    grim
    slurp

    # Clipboard management
    wl-clipboard

    # System monitoring (lightweight)
    neofetch

    # Network tools (essential)
    wget
    curl

    # File synchronization
    rsync

    # Audio tools
    pavucontrol # Audio control GUI

    # Mobile development
    android-tools # ADB for mobile development
  ];

  # Laptop-specific program configurations
  programs.firefox = {
    enable = true;
    profiles.default = {
      settings = {
        # Battery-optimized Firefox settings
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "media.ffmpeg.vaapi.enabled" = true;
        "dom.security.https_only_mode" = true;
        "privacy.trackingprotection.enabled" = true;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;

        # Power saving optimizations
        "media.autoplay.default" = 5; # Block autoplay to save battery
        "layers.acceleration.force-enabled" = true; # GPU acceleration
        "gfx.webrender.all" = true; # WebRender for efficiency
      };
    };
  };

  # Chrome configuration optimized for laptops
  programs.chromium = {
    enable = true;
    package = lib.mkDefault pkgs.google-chrome;
    commandLineArgs = [
      # Wayland support for better mobile integration
      "--enable-features=UseOzonePlatform,WaylandWindowDecorations"
      "--ozone-platform=wayland"

      # Power efficiency optimizations
      "--enable-gpu-rasterization"
      "--enable-zero-copy"
      "--ignore-gpu-blocklist"
      "--disable-background-timer-throttling"

      # Battery saving features
      "--enable-aggressive-domstorage-flushing"
      "--enable-memory-pressure-signal"
      "--max-unused-resource-memory-usage-percentage=5"

      # Network optimizations for mobile connections
      "--enable-quic"
      "--aggressive-cache-discard"

      # Mobile-friendly flags
      "--touch-events=enabled"
      "--enable-pinch"
    ];
  };

  # Git configuration for mobile development
  programs.git = {
    enable = true;
    delta.enable = true;
    extraConfig = {
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;
      rebase.autoStash = true;
      # Mobile-friendly settings
      core.autocrlf = "input";
      merge.tool = "vimdiff";
    };
  };

  # Mobile development environment
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
