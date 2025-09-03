# Server Admin Profile - Minimal headless configuration for server administration
# Used by: DEX5550, P510 (server mode), other headless servers
{ lib, pkgs, config, ... }: {
  imports = [
    # Import common home manager modules
    ../../browsers/default.nix # Browser options only (no implementation when disabled)
    ../../desktop/terminals/default.nix # Terminal options (provides alacritty, foot, etc.)
    ../../shell/default.nix # CLI shell configuration
    ../../development/default.nix # Development tools
    ../../media/music.nix # Music configuration (CLI tools)
    ../../files.nix # File associations and utilities

    # Desktop option modules (options only, implementations disabled via features)
    ../../desktop/sway/default.nix # Provides desktop.sway option
    ../../desktop/dunst/default.nix # Provides desktop.dunst option
    ../../desktop/swaync/default.nix # Provides desktop.swaync option
    ../../desktop/zathura/default.nix # Provides desktop.zathura option
    ../../desktop/rofi/default.nix # Provides desktop.rofi option
    ../../desktop/obsidian/default.nix # Provides desktop.obsidian option
    ../../desktop/swaylock/default.nix # Provides swaylock option
    ../../desktop/flameshot/default.nix # Provides desktop.screenshots.flameshot option
    ../../desktop/kooha/default.nix # Provides desktop.screenshots.kooha option
    ../../desktop/remotedesktop/default.nix # Provides desktop.remotedesktop option

    # Program modules (provide programs.* options referenced by features system)
    ../../desktop/obs/default.nix # Provides programs.obs option
    ../../desktop/evince/default.nix # Provides programs.evince option
    ../../desktop/kdeconnect/default.nix # Provides programs.kdeconnect option
    ../../desktop/slack/default.nix # Provides programs.slack option
  ];

  # Server admin feature configuration - minimal headless setup
  features = {
    terminals = {
      enable = false; # Disable GUI terminals for headless server
      alacritty = false;
      foot = false;
      wezterm = false;
      kitty = false;
      ghostty = false;
    };

    editors = {
      enable = true; # Keep CLI editors enabled
      cursor = false; # GUI editor - disabled
      neovim = true; # CLI editor - essential for server admin
      vscode = false; # GUI editor - disabled
      zed = false; # GUI editor - disabled
      windsurf = false; # GUI editor - disabled
    };

    browsers = {
      enable = false; # Disable all browsers for headless server
      chrome = false;
      firefox = false;
      edge = false;
      brave = false;
      opera = false;
    };

    desktop = {
      enable = true; # Enable framework but disable all components
      # Note: This avoids feature system evaluation issues while keeping components disabled
      sway = false;
      dunst = false;
      swaync = false;
      zathura = false; # PDF viewer - not needed on server
      rofi = false; # Application launcher - not needed
      obsidian = false;
      swaylock = false;
      flameshot = false; # Screenshot tool - not needed
      kooha = false; # Screen recorder - not needed
      remotedesktop = false; # Not needed for headless server
      walker = false;

      # Communication and media
      obs = false;
      evince = false; # PDF viewer - not needed on server
      kdeconnect = false;
      slack = false; # GUI communication tool - disabled
    };

    cli = {
      enable = true; # Essential CLI tools for server administration
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
      enable = true; # Essential for server administration
      tmux = true;
      zellij = true;
    };

    gaming = {
      enable = false; # No gaming on servers
      steam = false;
    };

    development = {
      enable = true; # Keep development tools for server management
      languages = true; # Language support for scripting and automation
      workflow = true; # Workflow tools for automation
      productivity = false; # Disable GUI productivity apps
    };
  };

  # Server admin specific packages
  home.packages = with pkgs; [
    # System administration tools
    htop
    btop
    iotop
    ncdu
    tree
    rsync
    curl
    wget
    jq
    yq-go  # Use Go version consistently across all configurations

    # Network tools
    nmap
    netcat
    socat
    dig
    whois

    # File operations
    ripgrep
    fd
    sd

    # Archive tools
    unzip
    p7zip

    # Process management
    psmisc
    procps
  ];
}
