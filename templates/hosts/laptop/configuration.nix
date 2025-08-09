# Laptop template configuration.nix
# This file provides a comprehensive mobile-optimized laptop configuration
# Edit variables.nix to customize for your specific laptop needs
{ config
, lib
, pkgs
, system
, ...
}:
let
  vars = import ./variables.nix;
in
{
  imports = [
    # Hardware configuration (auto-generated)
    ./nixos/hardware-configuration.nix

    # GPU configuration based on variables
    (
      if vars.gpu == "amd"
      then ./nixos/amd.nix
      else if vars.gpu == "nvidia"
      then ./nixos/nvidia.nix
      else if vars.gpu == "intel"
      then ./nixos/intel.nix
      else ./nixos/none.nix
    )

    # Laptop-optimized modules
    ../../modules/desktop
    ../../modules/network
    ../../modules/development
    ../../modules/virtualization
    ../../modules/security
    ../../modules/monitoring
    ../../modules/shell
    ../../modules/mobile
  ];

  # System configuration
  system.stateVersion = vars.stateVersion;
  networking.hostName = vars.hostName;
  time.timeZone = vars.timezone;
  i18n.defaultLocale = vars.locale;

  # Boot configuration optimized for laptops
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 2; # Quick boot for laptops
    };

    # Laptop-optimized kernel parameters
    kernelParams = [
      "quiet"
      "splash"
      "loglevel=3"
      "systemd.show_status=auto"
      "rd.udev.log_level=3"

      # Power management
      "acpi_enforce_resources=lax"
      "pcie_aspm=force"
      "iwlwifi.power_save=1"
      "iwlwifi.power_level=5"

      # Graphics optimizations
      "i915.enable_fbc=1"
      "i915.enable_psr=1"
      "i915.fastboot=1"
    ];

    # Fast boot optimizations
    initrd = {
      verbose = false;
      systemd.enable = true;
    };

    # Kernel modules for laptop hardware
    kernelModules = [ "kvm-intel" "kvm-amd" ];
    extraModulePackages = with config.boot.kernelPackages; [ ];
  };

  # User configuration
  users.users.${vars.userName} = {
    isNormalUser = true;
    description = vars.userFullName;
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "docker" "libvirtd" "scanner" "lp" ];
    hashedPasswordFile = config.age.secrets."user-password-${vars.userName}".path;
    openssh.authorizedKeys.keys = vars.sshPublicKeys;
    shell = pkgs.zsh;
  };

  # Enable essential programs
  programs = {
    zsh.enable = true;
    git.enable = true;
    vim.enable = true;
    firefox.enable = true;
    thunar.enable = true;
  };

  # Feature configuration optimized for laptops
  features = {
    # Desktop environment
    desktop = {
      enable = true;
      wayland = true;
      hyprland = vars.features.desktop.hyprland;
      gnome = vars.features.desktop.gnome;
      audio = true;
      bluetooth = true;
    };

    # Mobile-specific features
    mobile = {
      enable = true;
      powerManagement = true;
      batteryOptimization = true;
      touchpad = true;
      wifi = true;
      bluetooth = true;
      hotkeys = true;
      screenBrightness = true;
      suspend = true;
    };

    # Network services
    network = {
      enable = true;
      tailscale = vars.tailscale.enable;
      networkManager = true;
      wifi = true;
      bluetooth = true;
    };

    # Development tools
    development = {
      enable = vars.features.development;
      git = vars.features.development;
      python = vars.features.development;
      nodejs = vars.features.development;
      docker = vars.features.docker;
      vscode = vars.features.development;
    };

    # Virtualization (lighter for laptops)
    virtualization = {
      enable = vars.features.virtualization;
      docker = vars.features.docker;
      podman = false; # Prefer Docker for laptops
      libvirt = vars.features.libvirt;
      microvm = vars.features.microvm;
    };

    # Shell environment
    shell = {
      enable = true;
      modern = true;
      zsh = true;
      tmux = true;
      starship = true;
    };

    # Monitoring (lightweight for laptops)
    monitoring = {
      enable = vars.features.monitoring.enable;
      mode = vars.features.monitoring.mode;
      serverHost = vars.features.monitoring.serverHost;

      features = {
        nodeExporter = true;
        systemdExporter = true;
        mobileMetrics = true;
        batteryMetrics = true;
        thermalMetrics = true;
      };
    };

    # AI providers
    ai = {
      providers = {
        enable = vars.features.ai.enable;
        defaultProvider = vars.features.ai.defaultProvider;
        enableFallback = vars.features.ai.enableFallback;

        openai.enable = vars.features.ai.openai;
        anthropic.enable = vars.features.ai.anthropic;
        gemini.enable = vars.features.ai.gemini;
        ollama.enable = vars.features.ai.ollama;
      };
    };

    # Security
    security = {
      enable = true;
      firewall = true;
      apparmor = true;
    };
  };

  # Tailscale configuration
  networking.tailscale = lib.mkIf vars.tailscale.enable {
    enable = true;
    authKeyFile = config.age.secrets.tailscale-auth-key.path;
    hostname = "${vars.hostName}-laptop";
    acceptDns = false; # CRITICAL: Prevent DNS conflicts
    useRoutingFeatures = "client"; # Laptop is a client
    permitCertUid = vars.userName;
  };

  # DNS configuration for laptops
  services.resolved = {
    enable = true;
    fallbackDns = vars.network.fallbackDns;
    domains = [ "~${vars.network.localDomain}" ];
    dnssec = lib.mkForce "false";
    llmnr = lib.mkForce "false";
  };

  # Network configuration optimized for mobile use
  networking = {
    # Use NetworkManager for laptops
    networkmanager = {
      enable = true;
      wifi.powersave = true;
      ethernet.macAddress = "random";
      wifi.macAddress = "random";
      dns = "systemd-resolved";
    };

    # Disable networkd for laptops (use NetworkManager)
    useNetworkd = false;
    dhcpcd.enable = false;

    # Firewall configuration
    firewall = {
      enable = true;
      allowedTCPPorts = vars.network.openPorts.tcp;
      allowedUDPPorts = vars.network.openPorts.udp;
      allowPing = true;
      logReversePathDrops = false; # Reduce log spam on laptops
      logRefusedConnections = false;
    };

    # Host mappings for local services
    hosts = vars.network.hostMappings;
  };

  # Power management for laptops
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "powersave"; # Battery optimization
    powertop.enable = true;
    scsiLinkPolicy = "min_power";
  };

  # Laptop-specific services
  services = {
    # Power management
    thermald.enable = lib.mkDefault true;
    auto-cpufreq.enable = true;
    upower.enable = true;

    # Audio
    pipewire = {
      enable = true;
      audio.enable = true;
      pulse.enable = true;
      jack.enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      wireplumber.enable = true;
    };

    # Bluetooth
    blueman.enable = true;

    # Printing
    printing = {
      enable = true;
      drivers = with pkgs; [ hplip epson-escpr ];
    };

    # Scanning
    sane = {
      enable = true;
      extraBackends = with pkgs; [ hplipWithPlugin ];
    };

    # Location services
    geoclue2.enable = true;

    # Display management
    xserver = {
      enable = true;
      displayManager = {
        gdm = {
          enable = vars.features.desktop.gnome;
          wayland = true;
        };
        autoLogin = {
          enable = vars.autoLogin.enable;
          user = lib.mkIf vars.autoLogin.enable vars.userName;
        };
      };

      desktopManager.gnome.enable = vars.features.desktop.gnome;
    };

    # Wayland compositor
    greetd = lib.mkIf vars.features.desktop.hyprland {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
          user = "greeter";
        };
      };
    };
  };

  # Desktop environment configuration
  programs.hyprland = lib.mkIf vars.features.desktop.hyprland {
    enable = true;
    package = pkgs.hyprland;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
  };

  # Fonts for laptops
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      # System fonts
      dejavu_fonts
      liberation_ttf
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji

      # Programming fonts
      fira-code
      fira-code-symbols
      jetbrains-mono
      source-code-pro

      # Google Fonts
      google-fonts

      # Icon fonts
      font-awesome
      material-design-icons
    ];

    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = [ "Noto Serif" ];
        sansSerif = [ "Noto Sans" ];
        monospace = [ "JetBrains Mono" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };

  # Essential laptop packages
  environment.systemPackages = with pkgs; [
    # Desktop applications
    firefox
    google-chrome
    thunderbird
    libreoffice
    gimp
    vlc

    # System utilities
    gnome.gnome-system-monitor
    gnome.gnome-disk-utility
    gnome.file-roller

    # Development tools
    vscode
    git
    curl
    wget

    # Terminal applications
    htop
    neofetch
    tree
    unzip

    # Network tools
    networkmanagerapplet
    blueman

    # Audio/Video
    pavucontrol
    alsa-utils
    pulseaudio

    # Graphics
    mesa
    vulkan-tools

    # Power management
    powertop
    acpi

    # File management
    thunar
    xfce.thunar-volman
    xfce.thunar-archive-plugin

    # Screenshot and screen recording
    grim
    slurp
    wl-clipboard

    # Laptop-specific tools
    brightnessctl # Brightness control
    playerctl # Media control
    pamixer # Audio control

    # Communication
    discord
    slack
    zoom-us

    # Productivity
    obsidian
    notion-app-enhanced

    # Entertainment
    spotify
    steam
  ];

  # Hardware support for laptops
  hardware = {
    # Audio
    pulseaudio.enable = false; # Using pipewire

    # Bluetooth
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
      };
    };

    # Graphics acceleration
    graphics = {
      enable = true;
      enable32Bit = true;
    };

    # Webcam
    facetimehd.enable = lib.mkDefault false; # Enable for MacBook users

    # Trackpad
    trackpoint.enable = lib.mkDefault false; # Enable for ThinkPads

    # Sensors
    sensor.iio.enable = true; # Screen rotation

    # Firmware
    enableRedistributableFirmware = true;
    enableAllFirmware = true;
  };

  # XDG configuration
  xdg = {
    portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        (lib.mkIf vars.features.desktop.hyprland xdg-desktop-portal-hyprland)
      ];
    };

    mime.enable = true;

    userDirs = {
      enable = true;
      createDirectories = true;
    };
  };

  # Security configuration for laptops
  security = {
    polkit.enable = true;
    rtkit.enable = true;

    # Sudo configuration
    sudo = {
      enable = true;
      wheelNeedsPassword = true;
    };

    # PAM configuration
    pam.services = {
      login.enableGnomeKeyring = true;
      gdm.enableGnomeKeyring = true;
    };
  };

  # Systemd services optimization for laptops
  systemd = {
    # User services
    user.services = {
      # Battery optimization
      powertop-auto-tune = {
        enable = vars.mobile.batteryOptimization;
        description = "PowerTOP Auto Tune";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.powertop}/bin/powertop --auto-tune";
        };
        wantedBy = [ "default.target" ];
      };
    };

    # System services
    services = {
      # Disable unnecessary services for laptops
      NetworkManager-wait-online.enable = lib.mkForce false;

      # Laptop-specific services
      laptop-mode = {
        enable = vars.mobile.batteryOptimization;
        description = "Laptop Mode";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash -c 'echo 5 > /proc/sys/vm/laptop_mode'";
          RemainAfterExit = true;
        };
        wantedBy = [ "multi-user.target" ];
      };
    };
  };

  # Sleep and suspend configuration
  systemd.sleep.extraConfig = lib.mkIf vars.mobile.suspend ''
    HibernateDelaySec=30min
    SuspendState=mem
  '';

  # Locale and input methods
  i18n = {
    defaultLocale = vars.locale;
    extraLocaleSettings = {
      LC_ADDRESS = vars.locale;
      LC_IDENTIFICATION = vars.locale;
      LC_MEASUREMENT = vars.locale;
      LC_MONETARY = vars.locale;
      LC_NAME = vars.locale;
      LC_NUMERIC = vars.locale;
      LC_PAPER = vars.locale;
      LC_TELEPHONE = vars.locale;
      LC_TIME = vars.locale;
    };
  };

  # Console configuration
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
  };

  # Automatic system maintenance (optional for laptops)
  system.autoUpgrade = {
    enable = vars.autoUpgrade.enable;
    allowReboot = vars.autoUpgrade.allowReboot;
    dates = vars.autoUpgrade.schedule;
    flake = "github:olafkfreund/nixos-config";
  };

  # Garbage collection optimized for laptops
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d"; # More frequent for limited storage
    };

    # Optimize store
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };

    settings = {
      # Build settings for laptops
      max-jobs = "auto";
      cores = 0;

      # Experimental features
      experimental-features = [ "nix-command" "flakes" ];

      # Binary cache settings
      trusted-users = [ "root" vars.userName ];
      substituters = vars.nix.substituters;
      trusted-public-keys = vars.nix.trustedPublicKeys;

      # Laptop optimizations
      auto-optimise-store = true;
      keep-outputs = false; # Save space
      keep-derivations = false; # Save space
    };
  };

  # Age secrets configuration
  age.secrets = {
    "user-password-${vars.userName}" = {
      file = ../../secrets/user-password-${vars.userName}.age;
      owner = vars.userName;
      group = "users";
    };

    # Tailscale auth key
    "tailscale-auth-key" = lib.mkIf vars.tailscale.enable {
      file = ../../secrets/tailscale-auth-key.age;
      owner = "root";
      group = "root";
    };

    # AI provider API keys (if enabled)
    "api-openai" = lib.mkIf vars.features.ai.openai {
      file = ../../secrets/api-openai.age;
      owner = vars.userName;
      group = "users";
    };

    "api-anthropic" = lib.mkIf vars.features.ai.anthropic {
      file = ../../secrets/api-anthropic.age;
      owner = vars.userName;
      group = "users";
    };

    "api-gemini" = lib.mkIf vars.features.ai.gemini {
      file = ../../secrets/api-gemini.age;
      owner = vars.userName;
      group = "users";
    };
  };
}
