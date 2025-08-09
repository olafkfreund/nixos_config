# Headless/No GPU configuration for workstation template
{ pkgs
, lib
, ...
}: {
  # Minimal graphics support for headless systems
  hardware.graphics = {
    enable = true;
    enable32Bit = false; # Disable 32-bit support for headless
    extraPackages = with pkgs; [
      # Minimal packages for software rendering
      mesa
      mesa-demos
    ];
  };

  # Environment packages for headless monitoring
  environment.systemPackages = with pkgs; [
    # System monitoring (no GPU-specific tools)
    htop
    iotop
    nethogs

    # Basic utilities
    pciutils
    usbutils
    lshw

    # Remote access tools
    tigervnc # VNC server if needed

    # Virtualization monitoring
    libvirt
    virt-manager-qt # Headless VM management
  ];

  # Environment variables for headless operation
  environment.variables = {
    # Disable hardware acceleration
    LIBGL_ALWAYS_SOFTWARE = "1";
    GALLIUM_DRIVER = "llvmpipe";

    # Force software rendering
    WLR_RENDERER_ALLOW_SOFTWARE = "1";

    # Terminal-focused environment
    TERM = "xterm-256color";

    # Disable GPU-related variables
    # (Explicitly unset common GPU variables)
  };

  # No specific kernel modules for GPU
  boot.kernelModules = [ ];

  # Minimal kernel parameters
  boot.kernelParams = [
    "nomodeset" # Disable kernel modesetting
    "vga=normal" # Use basic VGA
    "quiet" # Quiet boot
  ];

  # Hardware-specific udev rules (minimal)
  services.udev.extraRules = ''
    # Basic device permissions
    KERNEL=="tty*", GROUP="tty", MODE="0664"
    KERNEL=="console", GROUP="tty", MODE="0664"
  '';

  # Power management optimized for efficiency
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "powersave"; # Maximum power efficiency
    powertop.enable = true; # Power optimization
  };

  # No GPU-specific gaming configuration
  programs.gamemode = {
    enable = false; # Disable gamemode for headless systems
  };

  # Audio configuration (minimal or disabled)
  services.pipewire = {
    enable = lib.mkDefault false; # Disable audio for true headless
    # If you need audio for headless streaming/recording:
    # enable = true;
    # extraConfig.pipewire = {
    #   "context.properties" = {
    #     "default.clock.rate" = 44100;  # Lower quality for efficiency
    #   };
    # };
  };

  # Disable audio entirely for headless
  hardware.pulseaudio.enable = lib.mkForce false;
  sound.enable = lib.mkDefault false;

  # Minimal hardware support
  hardware = {
    # Disable GPU-specific features
    enableAllFirmware = lib.mkDefault false;
    enableRedistributableFirmware = lib.mkDefault true; # Keep for network/storage

    # Basic hardware support only
    bluetooth.enable = lib.mkDefault false; # Usually not needed headless

    # Disable unnecessary hardware
    pulseaudio.enable = lib.mkForce false;
  };

  # Console-only configuration
  console = {
    enable = true;
    font = "Lat2-Terminus16";
    useXkbConfig = false; # No X11 keyboard config needed
  };

  # Disable X11 and display managers
  services.xserver = {
    enable = lib.mkDefault false; # No X11 for headless
  };

  # Disable desktop environments
  services.desktopManager.gnome.enable = lib.mkForce false;
  services.displayManager.gdm.enable = lib.mkForce false;

  # Disable Wayland compositors
  programs.hyprland.enable = lib.mkForce false;
  programs.sway.enable = lib.mkForce false;

  # Minimal system services
  systemd.services = {
    # Disable unnecessary services for headless
    NetworkManager-wait-online.enable = lib.mkForce false;
    systemd-networkd-wait-online.enable = lib.mkForce false;
  };

  # Network-focused configuration
  networking = {
    # Enable networkd for server-style networking
    useNetworkd = lib.mkDefault true;

    # Minimal network configuration
    dhcpcd.enable = lib.mkDefault false; # Use systemd-networkd instead
  };

  # Headless-optimized systemd network configuration
  systemd.network = {
    enable = true;
    networks = {
      "20-wired" = {
        matchConfig.Name = "en*";
        networkConfig = {
          DHCP = "ipv4";
          IPv6AcceptRA = true;
          MulticastDNS = false; # Disable for servers
          LLMNR = false; # Disable for servers
        };
        dhcpV4Config = {
          RouteMetric = 10;
          UseDNS = true;
        };
      };
    };
  };

  # SSH configuration for remote access
  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
    openFirewall = true;
  };

  # Firewall configuration for headless server
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ]; # SSH only by default
    allowedUDPPorts = [ ];

    # Strict firewall for headless servers
    allowPing = true;
    logReversePathDrops = true;
    logRefusedConnections = false; # Reduce log spam
    logRefusedPackets = false; # Reduce log spam
  };

  # Minimal font configuration
  fonts = {
    enableDefaultPackages = false; # Disable GUI fonts
    packages = with pkgs; [
      # Only console fonts
      terminus_font
      dejavu_fonts # Minimal font set
    ];
  };

  # Performance optimization for headless
  boot.kernel.sysctl = {
    # Network performance
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_max" = 134217728;
    "net.ipv4.tcp_rmem" = "4096 65536 134217728";
    "net.ipv4.tcp_wmem" = "4096 65536 134217728";

    # Memory management for servers
    "vm.swappiness" = 1; # Minimize swap usage
    "vm.dirty_ratio" = 10; # Conservative disk I/O
    "vm.dirty_background_ratio" = 5;

    # Disable unnecessary features
    "kernel.printk" = "3 3 3 3"; # Reduce kernel messages
  };

  # Disable unnecessary systemd services
  systemd.services = {
    # Disable desktop-related services
    accounts-daemon.enable = lib.mkForce false;
    rtkit-daemon.enable = lib.mkForce false;

    # Disable audio services
    alsa-state.enable = lib.mkForce false;

    # Keep essential services only
    sshd.enable = lib.mkDefault true;
  };

  # Remove GUI applications from system packages
  environment.systemPackages = lib.mkForce (with pkgs; [
    # Essential system tools only
    vim
    git
    curl
    wget
    htop
    iotop
    lsof
    tcpdump
    rsync

    # Network tools
    bind # dig, nslookup
    iproute2 # ip command
    ethtool # Network interface tools

    # System administration
    pciutils # lspci
    usbutils # lsusb
    util-linux # Various utilities
    procps # ps, top, etc.

    # File management
    tree
    file
    unzip
    tar
    gzip

    # Monitoring
    lm_sensors # Hardware sensors
    smartmontools # Disk health
  ]);

  # Systemd user services disabled
  systemd.user.services = { };

  # Minimal logging configuration
  services.journald.extraConfig = ''
    SystemMaxUse=100M
    MaxRetentionSec=1week
    Compress=yes
  '';

  # Disable unnecessary features
  documentation = {
    enable = lib.mkDefault false;
    doc.enable = lib.mkDefault false;
    info.enable = lib.mkDefault false;
    man.enable = lib.mkDefault true; # Keep man pages
    nixos.enable = lib.mkDefault false;
  };

  # Security configuration for headless
  security = {
    # Disable unnecessary security features that need GUI
    polkit.enable = lib.mkDefault false;
    rtkit.enable = lib.mkForce false;

    # Keep essential security
    sudo.enable = true;
    pam.services.sudo.requireWheel = true;
  };
}
