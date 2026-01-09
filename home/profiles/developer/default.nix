# Developer Profile - Development-focused configuration
# Used by: P620, P510 (development mode), workstation environments
{ pkgs, ... }: {
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
    ../../desktop/zathura/default.nix # PDF viewer for documentation
    ../../desktop/obsidian/default.nix # Note-taking for project docs
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
      zathura = true; # PDF viewer for documentation
      obsidian = true; # Note-taking and project documentation
      flameshot = true; # Screenshots for documentation
      kooha = true; # Screen recording for demos
      remotedesktop = true; # Remote development access

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
    nodejs_24 # Use nodejs_24 to match system-wide installation
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
    yq-go # Use Go version consistently across all configurations
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
    # awscli2
    terraform
    ansible
  ];

  # Program configurations for development
  programs = {
    # Git configuration for development
    git = {
      enable = true;
      settings = {
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
        pull.rebase = true;
        rebase.autoStash = true;
      };
    };

    # Delta (diff viewer) integration with Git
    delta = {
      enable = true;
      enableGitIntegration = true;
    };

    # Development environment configurations
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    # Claude Powerline - AI-powered statusline for Claude Code
    # Single-line layout: Directory | Git | Model (budget monitoring disabled for MAX subscription)
    claude-powerline = {
      enable = true;
      theme = "custom"; # Gruvbox Dark theme
      style = "powerline"; # Vim-style powerline separators
    };
  };
}
