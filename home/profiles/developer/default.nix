# Developer Profile - Development-focused configuration
# Used by: P620, P510 (development mode), workstation environments
{ lib, pkgs, config, ... }: {
  imports = [
    # Import common home manager modules
    ../../browsers/default.nix # Browser support for web development
    ../../shell/default.nix # CLI shell configuration
    ../../development/default.nix # Full development tools
    ../../media/music.nix # Music for coding sessions
    ../../files.nix # File associations and utilities

    # Desktop modules for development workflows
    ../../desktop/terminals/default.nix # Multiple terminal options
    ../../desktop/sway/default.nix # Window manager support
    ../../desktop/dunst/default.nix # Notification system
    ../../desktop/swaync/default.nix # Advanced notifications
    ../../desktop/zathura/default.nix # PDF viewer for documentation
    ../../desktop/rofi/default.nix # Application launcher
    ../../desktop/obsidian/default.nix # Note-taking for project docs
    ../../desktop/swaylock/default.nix # Screen locking
    ../../desktop/flameshot/default.nix # Screenshots for documentation
    ../../desktop/kooha/default.nix # Screen recording for demos
    ../../desktop/remotedesktop/default.nix # Remote development access

    # Program modules
    ../../desktop/obs/default.nix # Screen recording for presentations
    ../../desktop/evince/default.nix # PDF viewer for documentation
    ../../desktop/kdeconnect/default.nix # Mobile integration
    ../../desktop/slack/default.nix # Team communication
  ];

  # Developer feature configuration - comprehensive development setup
  features = {
    terminals = {
      enable = true; # Multiple terminals for different workflows
      alacritty = true;
      foot = true;
      wezterm = true;
      kitty = true;
      ghostty = true;
    };

    editors = {
      enable = true; # Full editor suite for different languages/workflows
      cursor = true; # AI-powered coding
      neovim = true; # Terminal-based editing
      vscode = true; # Primary IDE
      zed = true; # Modern editor
      windsurf = true; # Web-based development
    };

    browsers = {
      enable = true; # Multiple browsers for testing and development
      chrome = true; # Primary development browser
      firefox = true; # Alternative browser for testing
      edge = true; # Cross-browser testing
      brave = false; # Optional privacy-focused browser
      opera = false; # Optional alternative browser
    };

    desktop = {
      enable = true; # Full desktop environment for development
      sway = true; # Window manager
      dunst = false; # Use swaync instead
      swaync = true; # Advanced notification system
      zathura = true; # PDF viewer for documentation
      rofi = true; # Application launcher
      obsidian = true; # Note-taking and project documentation
      swaylock = true; # Screen locking
      flameshot = true; # Screenshots for documentation
      kooha = true; # Screen recording for demos
      remotedesktop = true; # Remote development access
      walker = true; # Advanced app launcher

      # Communication and media for development
      obs = true; # Screen recording for presentations
      evince = true; # Alternative PDF viewer
      kdeconnect = true; # Mobile integration for notifications
      slack = true; # Team communication
    };

    cli = {
      enable = true; # Essential CLI tools for development
      bat = true;
      direnv = true; # Development environment management
      fzf = true; # Fuzzy finding for file navigation
      lf = true;
      starship = true; # Enhanced prompt with git info
      yazi = true;
      zoxide = true; # Smart directory navigation
      gh = true; # GitHub CLI
      markdown = true; # Documentation tools
    };

    multiplexers = {
      enable = true; # Session management for long-running tasks
      tmux = true;
      zellij = true;
    };

    gaming = {
      enable = false; # Focus on development, disable gaming
      steam = false;
    };

    development = {
      enable = true; # Full development stack
      languages = true; # All programming languages
      workflow = true; # Full development workflow tools
      productivity = true; # Development productivity tools
    };
  };

  # Developer-specific packages
  home.packages = with pkgs; [
    # Version control and collaboration
    git
    gh
    git-lfs
    delta
    difftastic

    # Development tools
    docker
    docker-compose
    kubectl
    k9s
    helm

    # Language-specific tools
    nodejs
    python3
    go
    rustc
    cargo

    # Database tools
    postgresql
    sqlite
    redis

    # API development
    postman
    insomnia
    httpie

    # Text processing and analysis
    jq
    yq
    xmlstarlet

    # Performance and monitoring
    hyperfine
    tokei

    # File operations optimized for development
    ripgrep
    fd
    sd
    eza

    # Network development tools
    netcat
    socat
    wireshark

    # Documentation and writing
    pandoc
    graphviz

    # Container and virtualization
    podman
    buildah

    # Cloud development
    awscli2
    terraform
    ansible
  ];

  # Git configuration for development
  programs.git = {
    enable = true;
    delta.enable = true;
    extraConfig = {
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;
      rebase.autoStash = true;
    };
  };

  # Development environment configurations
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
