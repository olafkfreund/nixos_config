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

    # Host-specific configurations
    # ../../hosts/p510/nixos/env.nix  # File doesn't exist - removed
  ];

  # Profile metadata (comments only - not valid Home Manager options)
  # name = "dev-server";
  # type = "composition";
  # description = "Server with development capabilities for remote work";
  # combines = [ "server-admin" "developer" ];
  # host = "p510";

  # P510-specific feature overrides for server + development
  features = {
    # Force headless operation - completely disable desktop
    desktop = {
      enable = lib.mkForce false; # Completely disable desktop framework for headless server
    };

    # Disable GUI terminals for headless operation - override profile conflicts
    terminals = {
      enable = lib.mkForce false;
      alacritty = lib.mkForce false;
      foot = lib.mkForce false;
      wezterm = lib.mkForce false;
      kitty = lib.mkForce false;
      ghostty = lib.mkForce false;
    };

    # CLI-only editors for server development
    editors = {
      enable = lib.mkForce true;
      cursor = lib.mkForce false; # No GUI editors
      neovim = lib.mkForce true; # Primary editor for server development
      vscode = lib.mkForce false; # No GUI editors
      zed = lib.mkForce false; # No GUI editors
      windsurf = lib.mkForce false; # No web-based editors
    };

    # No browsers on headless server
    browsers = {
      enable = lib.mkForce false;
      chrome = lib.mkForce false;
      firefox = lib.mkForce false;
      edge = lib.mkForce false;
      brave = lib.mkForce false;
      opera = lib.mkForce false;
    };

    # Full development capabilities but CLI-focused
    development = {
      enable = true;
      languages = true; # Full language support for development
      workflow = true; # Development workflow tools
      productivity = lib.mkForce false; # No GUI productivity tools - override profile conflicts
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
    python3Packages.pynvml
    # nvtopPackages.nvidia - removed to avoid conflict with neofetch module's nvtopPackages.full

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
    # yq-go provided by developer/server-admin profiles

    # Text processing
    gnused
    gawk

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
    delta.enable = lib.mkForce true;
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
