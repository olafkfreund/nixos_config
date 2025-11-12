# P510 Home Configuration - Development Server Profile
# Uses dev-server composition (server-admin + developer)
{ lib, pkgs, config, ... }: {
  imports = [
    # Import common user configuration
    ../common/default.nix
    ./private.nix

    # Import server-admin and developer profiles
    ../../home/profiles/server-admin/default.nix
    ../../home/profiles/developer/default.nix

    # Minimal GNOME desktop for login access only
    ../../home/desktop/gnome/default.nix

    # Host-specific configurations
  ];

  # Profile metadata
  meta.profile = {
    name = "dev-server";
    type = "composition";
    description = "Server with development capabilities for remote work";
    combines = [ "server-admin" "developer" ];
    host = "p510";
  };

  # P510-specific feature overrides for server + development
  features = {
    # Enable desktop with GNOME
    desktop = {
      enable = true; # Enable framework for options
      # Enable GNOME for login but disable other desktop environments
      sway = false;
      zathura = false;
      obsidian = false;
      flameshot = false;
      kooha = false;
      remotedesktop = false;
      obs = false;
      evince = false;
      kdeconnect = false;
      slack = false;
    };

    # Disable GUI terminals for headless operation
    terminals = {
      enable = false;
      alacritty = false;
      foot = false;
      wezterm = false;
      kitty = false;
      ghostty = false;
    };

    # CLI-only editors for server development
    editors = {
      enable = true;
      cursor = false; # No GUI editors
      neovim = true; # Primary editor for server development
      vscode = false; # No GUI editors
      zed = false; # No GUI editors
      windsurf = false; # No web-based editors
    };

    # No browsers on headless server
    browsers = {
      enable = false;
      chrome = false;
      firefox = false;
      edge = false;
      brave = false;
      opera = false;
    };

    # Full development capabilities but CLI-focused
    development = {
      enable = true;
      languages = true; # Full language support for development
      workflow = true; # Development workflow tools
      productivity = false; # No GUI productivity tools
    };

    # No gaming on server
    gaming = {
      enable = false;
      steam = false;
    };

    # Enhanced CLI tools for server development
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

    # Session management essential for remote development
    multiplexers = {
      enable = true;
      tmux = true;
      zellij = true;
    };
  };

  # P510 development server specific packages
  home.packages = with pkgs; [
    # Server development essentials
    git
    gh
    docker
    docker-compose
    kubectl
    k9s

    # Intel Xeon + NVIDIA specific tools
    intel-gpu-tools
    nvidia-ml-py
    nvtop

    # Media server development (P510 hosts media services)
    ffmpeg
    imagemagick

    # Database tools for development
    postgresql
    redis
    sqlite

    # Network development and monitoring
    netcat
    socat
    nmap
    wireshark
    tcpdump

    # Performance analysis for server optimization
    htop
    btop
    iotop

    # File operations
    ripgrep
    fd
    sd
    tree

    # Archive and compression
    unzip
    p7zip

    # System analysis
    lsof
    strace

    # API development and testing
    curl
    wget
    httpie
    jq
    yq

    # Text processing
    sed
    awk

    # Process management
    psmisc
    procps

    # Disk and storage tools
    ncdu
    rsync
  ];

  # Enhanced git configuration for server development
  programs.git = {
    enable = true;
    delta.enable = true;
    extraConfig = {
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = true;
      rebase.autoStash = true;
      # Server-specific settings
      core.autocrlf = "input";
      merge.tool = "vimdiff";
      # Enhanced logging for server development
      log.oneline = true;
      status.showUntrackedFiles = "all";
    };
  };

  # Development environment for server
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
