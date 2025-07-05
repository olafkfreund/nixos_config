# Consolidated package sets for performance optimization
# This reduces redundant package declarations across modules
{
  pkgs,
  lib,
  ...
}: {
  # Core system packages - always needed
  core = with pkgs; [
    # System utilities
    coreutils
    findutils
    gnugrep
    gnused
    gawk
    which
    tree
    file
    
    # Network utilities  
    iproute2
    inetutils
    
    # Basic tools
    git
    curl
    wget
    unzip
    zip
  ];

  # Development package sets
  development = {
    # Common development tools
    common = with pkgs; [
      git
      gh
      lazygit
      direnv
      just
      jq
      yq
    ];

    # Language-specific sets
    python = with pkgs; [
      python3
      python3Packages.pip
      python3Packages.setuptools
      python3Packages.wheel
      python3Packages.virtualenv
      python3Packages.black
      python3Packages.flake8
      python3Packages.pylint
    ];

    rust = with pkgs; [
      rustc
      cargo
      rustfmt
      rust-analyzer
      clippy
    ];

    nodejs = with pkgs; [
      nodejs
      nodePackages.npm
      nodePackages.yarn
      nodePackages.pnpm
      nodePackages.typescript
      nodePackages.typescript-language-server
    ];

    go = with pkgs; [
      go
      gopls
      delve
    ];

    lua = with pkgs; [
      lua
      luajit
      lua-language-server
    ];

    nix = with pkgs; [
      nil
      nixd
      nixfmt-rfc-style
      nix-tree
      nix-diff
      nix-index
      nix-output-monitor
      nvd
    ];
  };

  # Desktop environment packages
  desktop = {
    # Wayland/Hyprland essentials
    wayland = with pkgs; [
      waybar
      rofi-wayland
      swww
      grim
      slurp
      wl-clipboard
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];

    # Common GUI applications
    apps = with pkgs; [
      firefox
      thunderbird
      obsidian
      code-cursor
      discord
      slack
      spotify
      vlc
      gimp
      inkscape
    ];

    # Fonts and theming
    fonts = with pkgs; [
      nerdfonts
      font-awesome
      material-design-icons
      source-code-pro
      jetbrains-mono
    ];
  };

  # Virtualization and containers
  virtualization = {
    docker = with pkgs; [
      docker-compose
      docker-client
      docui
      docker-gc
      lazydocker
      earthly
    ];

    vm = with pkgs; [
      virt-manager
      qemu
      libvirt
      spice
      spice-gtk
      spice-protocol
    ];

    kubernetes = with pkgs; [
      kubectl
      kubectx
      k9s
      helm
      argocd
      flux
    ];
  };

  # Cloud and infrastructure tools
  cloud = {
    aws = with pkgs; [
      awscli2
      aws-sam-cli
      ssm-session-manager-plugin
    ];

    azure = with pkgs; [
      azure-cli
      azure-functions-core-tools
    ];

    terraform = with pkgs; [
      terraform
      terragrunt
      terraform-docs
      tflint
    ];
  };

  # Security tools
  security = with pkgs; [
    gnupg
    pinentry-gtk2
    pass
    _1password-gui
    _1password
    yubikey-manager
    yubikey-manager-qt
  ];

  # Media and entertainment
  media = with pkgs; [
    vlc
    mpv
    ffmpeg
    spotify
    discord
    obs-studio
    audacity
  ];

  # System monitoring and management
  monitoring = with pkgs; [
    htop
    btop
    iotop
    nethogs
    bandwhich
    duf
    ncdu
    systemctl-tui
  ];

  # Network tools
  network = with pkgs; [
    nmap
    wireshark
    tcpdump
    iperf3
    mtr
    dnsutils
    ldns
    ipcalc
    dig
  ];
}