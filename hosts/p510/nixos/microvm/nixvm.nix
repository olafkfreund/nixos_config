{
  config,
  lib,
  pkgs,
  ...
}: let
  username = "olafkfreund";
  hostname = "nixvm";
  mac = "02:00:00:00:00:10"; # Unique MAC address
  ip = "192.168.1.210/24"; # Unique IP address
in {
  # MicroVM configuration
  microvm = {
    enable = true;
    hypervisor = "qemu";

    # Resource allocation - balanced for general use
    mem = 8192; # 8GB RAM
    vcpu = 4; # 4 CPUs

    # CPU configuration for better performance
    qemuParams = [
      "-cpu host" # Use host CPU features
      "-smp 4,sockets=1,cores=4,threads=1" # Explicit CPU topology
    ];

    # Network interface configuration
    interfaces = [
      {
        type = "tap";
        id = hostname;
        mac = mac;
      }
    ];

    # Shared storage configuration
    shares = [
      {
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
      }
    ];

    # Storage configuration with larger volumes for general use
    volumes = [
      {
        mountPoint = "/";
        image = "nixvm-root.img";
        size = 20480; # 20GB for root
      }
      {
        mountPoint = "/home";
        image = "nixvm-home.img";
        size = 30720; # 30GB for home
      }
      {
        mountPoint = "/var";
        image = "nixvm-var.img";
        size = 10240; # 10GB for var
      }
    ];

    # Auto-start configuration
    autostart = true;

    # Socket activation for better integration with host system
    socket = true;

    # Graphics support for GUI applications
    graphics = {
      enable = true;
      width = 1920;
      height = 1080;
    };
  };

  # Basic system configuration
  system.stateVersion = "24.11";

  # Set hostname explicitly
  networking.hostName = hostname;

  # Use systemd-networkd for networking
  systemd.network = {
    enable = true;
    networks."20-lan" = {
      matchConfig.Type = "ether";
      networkConfig = {
        Address = [ip];
        Gateway = "192.168.1.254";
        DNS = ["8.8.8.8" "8.8.4.4"];
        IPv6AcceptRA = false;
        DHCP = "no";
      };
      linkConfig = {
        MTUBytes = "1500"; # Standard MTU
      };
    };
  };

  # Configure firewall
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22 # SSH
      80 # HTTP
      443 # HTTPS
    ];
    allowPing = true;
  };

  # Nix configuration
  nix = {
    enable = true;
    settings = {
      extra-experimental-features = ["nix-command" "flakes"];
      trusted-users = ["root" username];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };

  # Security configuration
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  # User configuration
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "audio" "video" "docker"];
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCMqMzUgRe2K350QBbQXbJFxVomsQbiIEw/ePUzjbyALklt5gMyo/yxbCWaKV1zeL4baR/vS5WOp9jytxceGFDaoJ7/O8yL4F2jj96Q5BKQOAz3NW/+Hmj/EemTOvVJWB1LQ+V7KgCbkxv6ZcUwL5a5+2QoujQNL5yVL3ZrIXv6LuKg8w8wykl57zDcJGgYsF+05oChswAmTFXI7hR5MdQgMGNM/eN78VZjSKJYGgeujoJg4BPQ6VE/qfIcJaPmuiiJBs0MDYIB8pKeSImXCDqYWEL6dZkSyro8HHHMAzFk1YP+pNIWVi8l3F+ajEFrEpTYKvdsZ4TiP/7CBaaI+0yVIq1mQ100AWeUiTn89iF8yqAgP8laLgMqZbM15Gm5UD7+g9/zsW0razyuclLogijvYRTMKt8vBa/rEfcx+qs8CuIrkXnD/KGfvoMDRgniWz8teaV1zfdDrkd6BhPVc5P3hI6gDY/xnSeijyyXL+XDE1ex6nfW5vNCwMiAWfDM+6k= olafkfreund@razer"
    ];
  };

  # Enable SSH server
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # Desktop environment (GNOME)
  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
  };

  # Desktop environment
  services.desktopManager.gnome.enable = true;

  # Audio support
  sound.enable = true;
  services.pulseaudio.enable = true;

  # Virtualization support
  virtualisation = {
    docker = {
      enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };

    # Nested virtualization if needed
    libvirtd = {
      enable = true;
      qemu.package = pkgs.qemu_kvm;
    };
  };

  # System packages
  environment.systemPackages = with pkgs; [
    # System tools
    vim
    wget
    curl
    git
    tmux
    htop
    iftop
    pciutils
    usbutils
    ncdu

    # Development
    vscode
    gnumake
    gcc
    python3
    nodejs

    # Utilities
    unzip
    zip
    file
    tree
    ripgrep
    fd

    # GUI applications
    firefox
    thunderbird
    libreoffice
    vlc

    # System administration
    gparted
    ethtool
    tcpdump
    wireshark

    # Graphics tools
    gimp
    inkscape

    # Terminal emulator
    alacritty
  ];

  # System optimization
  boot = {
    # Enable tmpfs for /tmp
    tmpOnTmpfs = true;

    # Kernel parameters
    kernelParams = [
      "mitigations=auto" # Performance-security balance
    ];

    # Kernel sysctl settings
    kernel.sysctl = {
      # Memory management
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;

      # Network settings
      "net.core.rmem_max" = 16777216;
      "net.core.wmem_max" = 16777216;

      # File descriptor limits
      "fs.file-max" = 1048576;
      "fs.inotify.max_user_watches" = 524288;
    };
  };

  # Fonts
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    jetbrains-mono
    font-awesome
  ];

  # Locale and time settings
  i18n.defaultLocale = "en_US.UTF-8";
  time.timeZone = "Europe/Berlin";

  # Enable automatic updates
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    flake = "github:olafkfreund/nixos_config";
    flags = ["--update-input" "nixpkgs" "--no-write-lock-file"];
  };

  # Automatic optimizations
  systemd.tmpfiles.rules = [
    "d /tmp 1777 root root 1d" # Clear /tmp daily
  ];
}
