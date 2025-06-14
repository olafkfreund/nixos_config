{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
  ];

  # Boot configuration
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    # Kernel parameters for gaming/performance
    kernelParams = [
      "quiet"
      "splash"
    ];

    # Clean /tmp on boot
    tmp.cleanOnBoot = true;
  };

  # Network configuration
  networking = {
    hostName = "workstation"; # Change this
    networkmanager.enable = true;

    # Firewall with desktop-friendly defaults
    firewall = {
      enable = true;
      allowPing = true;
      # Common ports for development
      allowedTCPPorts = [3000 8080 8000];
    };
  };

  # Internationalization
  time.timeZone = "Europe/London"; # Change as needed
  i18n = {
    defaultLocale = "en_GB.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_GB.UTF-8";
      LC_IDENTIFICATION = "en_GB.UTF-8";
      LC_MEASUREMENT = "en_GB.UTF-8";
      LC_MONETARY = "en_GB.UTF-8";
      LC_NAME = "en_GB.UTF-8";
      LC_NUMERIC = "en_GB.UTF-8";
      LC_PAPER = "en_GB.UTF-8";
      LC_TELEPHONE = "en_GB.UTF-8";
      LC_TIME = "en_GB.UTF-8";
    };
  };

  # User configuration
  users.users.username = {
    # Change 'username'
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "video"
      "docker"
      "libvirtd"
    ];
    shell = pkgs.zsh;
    # openssh.authorizedKeys.keys = [ "your-ssh-key" ];
  };

  # Security
  security = {
    sudo.wheelNeedsPassword = false;
    rtkit.enable = true;
    polkit.enable = true;
  };

  # Desktop Environment - Hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Display Manager
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  # XDG Portal
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    config.common.default = "hyprland";
  };

  # Audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = false;
  };

  # Hardware
  hardware = {
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };

    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };

  # Fonts
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    font-awesome
    (nerdfonts.override {fonts = ["FiraCode" "DroidSansMono"];})
  ];

  # Development tools
  environment.systemPackages = with pkgs; [
    # Desktop utilities
    kitty
    alacritty
    firefox
    chromium
    thunar
    file-roller
    pavucontrol
    blueman
    grim
    slurp
    wl-clipboard
    rofi-wayland
    waybar
    dunst

    # Development
    git
    gh
    vscode
    docker
    docker-compose
    nodejs
    npm
    yarn
    python3
    python3Packages.pip
    rustc
    cargo

    # System utilities
    wget
    curl
    git
    vim
    neovim
    htop
    btop
    tree
    file
    which
    unzip
    zip
    tar
    gzip

    # Network tools
    dig
    nmap
    nettools

    # System monitoring
    lsof
    pciutils
    usbutils

    # Media
    vlc
    mpv
    gimp
    inkscape
    obs-studio
  ];

  # Services
  services = {
    # Printing
    printing.enable = true;

    # Location services
    geoclue2.enable = true;

    # File services
    gvfs.enable = true;
    udisks2.enable = true;

    # Development services
    docker.enable = true;
  };

  # Virtualization
  virtualisation = {
    libvirtd.enable = true;
    docker.enable = true;
  };

  # Programs
  programs = {
    zsh.enable = true;
    git.enable = true;
    dconf.enable = true;
  };

  # Enable Nix flakes
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    auto-optimise-store = true;
    trusted-users = ["root" "@wheel"];
  };

  # Garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # System state version
  system.stateVersion = "24.11";
}
