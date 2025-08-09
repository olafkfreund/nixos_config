# Server template configuration.nix
# This file provides a comprehensive server configuration template
# Edit variables.nix to customize for your specific server needs
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

    # Server-optimized modules
    ../../modules/server
    ../../modules/network
    ../../modules/security
    ../../modules/monitoring
    ../../modules/virtualization
    ../../modules/development
    ../../modules/shell
  ];

  # System configuration
  system.stateVersion = vars.stateVersion;
  networking.hostName = vars.hostName;
  time.timeZone = vars.timezone;
  i18n.defaultLocale = vars.locale;

  # Boot configuration optimized for servers
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 3; # Quick boot for servers
    };

    # Server-optimized kernel parameters
    kernelParams = [
      "quiet"
      "loglevel=3"
      "systemd.show_status=auto"
      "rd.udev.log_level=3"
      "mitigations=auto"
    ];

    # Enable KSM for memory efficiency
    kernel.sysctl = {
      "kernel.kptr_restrict" = 2;
      "kernel.dmesg_restrict" = 1;
      "kernel.printk" = "3 3 3 3";
      "kernel.unprivileged_bpf_disabled" = 1;
      "net.core.bpf_jit_harden" = 2;
      "dev.tty.ldisc_autoload" = 0;
      "vm.unprivileged_userfaultfd" = 0;
      "kernel.kexec_load_disabled" = 1;
      "kernel.sysrq" = 0;
      "kernel.unprivileged_userns_clone" = 0;
      "kernel.perf_event_paranoid" = 3;
      "net.ipv4.tcp_syncookies" = 1;
      "net.ipv4.tcp_rfc1337" = 1;
      "net.ipv4.conf.default.rp_filter" = 1;
      "net.ipv4.conf.all.rp_filter" = 1;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.secure_redirects" = 0;
      "net.ipv4.conf.default.secure_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
    };

    # Disable initrd modules we don't need
    initrd.availableKernelModules = lib.mkForce [
      "xhci_pci"
      "ehci_pci"
      "ahci"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
  };

  # User configuration
  users.users.${vars.userName} = {
    isNormalUser = true;
    description = vars.userFullName;
    extraGroups = [ "wheel" "networkmanager" "docker" "libvirtd" ];
    hashedPasswordFile = config.age.secrets."user-password-${vars.userName}".path;
    openssh.authorizedKeys.keys = vars.sshPublicKeys;
    shell = pkgs.zsh;
  };

  # Root user configuration
  users.users.root = {
    hashedPasswordFile = config.age.secrets."user-password-root".path;
    openssh.authorizedKeys.keys = vars.sshPublicKeys;
  };

  # Enable essential programs
  programs = {
    zsh.enable = true;
    git.enable = true;
    vim.enable = true;
    tmux.enable = true;
  };

  # Feature configuration optimized for servers
  features = {
    # Core server features
    server = {
      enable = true;
      headless = vars.headless;
      monitoring = true;
      backup = true;
    };

    # Network services
    network = {
      enable = true;
      tailscale = vars.tailscale.enable;
      firewall = true;
      fail2ban = true;
    };

    # Security hardening
    security = {
      enable = true;
      hardening = true;
      audit = true;
      selinux = false; # Usually disabled for NixOS
    };

    # Development tools (minimal for servers)
    development = {
      enable = vars.features.development;
      minimal = true;
      git = true;
      python = vars.features.development;
      docker = vars.features.docker;
    };

    # Virtualization for containers and VMs
    virtualization = {
      enable = vars.features.virtualization;
      docker = vars.features.docker;
      podman = vars.features.podman;
      libvirt = vars.features.libvirt;
      lxc = vars.features.lxc;
    };

    # Shell environment
    shell = {
      enable = true;
      modern = true;
      zsh = true;
      tmux = true;
      minimal = true; # Server-optimized shell
    };

    # Monitoring and observability
    monitoring = {
      enable = vars.features.monitoring.enable;
      mode = vars.features.monitoring.mode;
      serverHost = vars.features.monitoring.serverHost;

      features = {
        nodeExporter = true;
        systemdExporter = true;
        nixosMetrics = true;
        dockerMetrics = vars.features.docker;
        storageMetrics = true;
      };
    };

    # AI providers (optional for servers)
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

    # Optional services
    mediaServer = {
      enable = vars.features.mediaServer.enable;
      plex = vars.features.mediaServer.plex;
      jellyfin = vars.features.mediaServer.jellyfin;
      transmission = vars.features.mediaServer.transmission;
      nzbget = vars.features.mediaServer.nzbget;
      sonarr = vars.features.mediaServer.sonarr;
      radarr = vars.features.mediaServer.radarr;
    };

    # Database services
    database = {
      enable = vars.features.database.enable;
      postgresql = vars.features.database.postgresql;
      mysql = vars.features.database.mysql;
      redis = vars.features.database.redis;
      mongodb = vars.features.database.mongodb;
    };

    # Web services
    webServices = {
      enable = vars.features.webServices.enable;
      nginx = vars.features.webServices.nginx;
      apache = vars.features.webServices.apache;
      nodejs = vars.features.webServices.nodejs;
    };
  };

  # Tailscale configuration
  networking.tailscale = lib.mkIf vars.tailscale.enable {
    enable = true;
    authKeyFile = config.age.secrets.tailscale-auth-key.path;
    hostname = "${vars.hostName}-server";
    acceptDns = false; # CRITICAL: Prevent DNS conflicts
    useRoutingFeatures = "both"; # Server can route traffic
    permitCertUid = vars.userName;
  };

  # DNS configuration for servers
  services.resolved = {
    enable = true;
    fallbackDns = vars.network.fallbackDns;
    domains = [ "~${vars.network.localDomain}" ];
    dnssec = lib.mkForce "false";
    llmnr = lib.mkForce "false";
  };

  # Network configuration optimized for servers
  networking = {
    # Use networkd for server-grade networking
    useNetworkd = true;
    dhcpcd.enable = false;

    # Firewall configuration
    firewall = {
      enable = true;
      allowedTCPPorts = vars.network.openPorts.tcp;
      allowedUDPPorts = vars.network.openPorts.udp;
      allowPing = true;
      logReversePathDrops = true;
      logRefusedConnections = false; # Reduce log spam
      logRefusedPackets = false;
    };

    # Host mappings for local services
    hosts = vars.network.hostMappings;

    # Network interfaces
    interfaces = vars.network.interfaces;
  };

  # Systemd network configuration
  systemd.network = {
    enable = true;
    networks."20-wired" = {
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

  # SSH configuration for servers
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
      AllowUsers = [ vars.userName ];
      MaxAuthTries = 3;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
      TCPKeepAlive = false;
      Compression = false;
      AllowAgentForwarding = false;
      AllowTcpForwarding = false;
      X11Forwarding = false;
      PermitTunnel = false;
      GatewayPorts = "no";
      PermitUserEnvironment = false;
    };
    openFirewall = true;
    ports = [ 22 ];
  };

  # Disable X11 and desktop services for headless servers
  services.xserver.enable = lib.mkForce false;
  services.displayManager.gdm.enable = lib.mkForce false;
  services.desktopManager.gnome.enable = lib.mkForce false;
  programs.hyprland.enable = lib.mkForce false;
  programs.sway.enable = lib.mkForce false;

  # Disable audio for headless servers
  services.pipewire.enable = lib.mkDefault false;
  hardware.pulseaudio.enable = lib.mkForce false;
  sound.enable = lib.mkDefault false;

  # Console configuration
  console = {
    enable = true;
    font = "Lat2-Terminus16";
    useXkbConfig = false;
  };

  # Minimal fonts for servers
  fonts = {
    enableDefaultPackages = false;
    packages = with pkgs; [
      terminus_font
      dejavu_fonts
    ];
  };

  # Essential system packages for servers
  environment.systemPackages = with pkgs; [
    # System administration
    vim
    git
    curl
    wget
    htop
    iotop
    lsof
    tcpdump
    rsync
    tree
    file
    unzip
    tar
    gzip

    # Network tools
    bind # dig, nslookup
    iproute2 # ip command
    ethtool # Network interface tools
    iperf3 # Network performance testing
    mtr # Network diagnostics
    nmap # Network scanner

    # System monitoring
    lm_sensors # Hardware sensors
    smartmontools # Disk health
    sysstat # System statistics
    nethogs # Network usage per process
    iftop # Network bandwidth usage

    # Hardware tools
    pciutils # lspci
    usbutils # lsusb
    util-linux # Various utilities
    procps # ps, top, etc.
    dmidecode # Hardware information

    # Security tools
    fail2ban # Intrusion prevention
    logwatch # Log analysis
    rkhunter # Rootkit hunter

    # Backup and archiving
    borgbackup # Deduplicating backup
    duplicity # Encrypted backup
    rdiff-backup # Incremental backup

    # Automation
    ansible # Configuration management
    terraform # Infrastructure as code
  ];

  # Systemd service optimizations for servers
  systemd = {
    # Disable unnecessary services
    services = {
      NetworkManager-wait-online.enable = lib.mkForce false;
      systemd-networkd-wait-online.enable = lib.mkForce false;
      accounts-daemon.enable = lib.mkForce false;
      rtkit-daemon.enable = lib.mkForce false;
      alsa-state.enable = lib.mkForce false;
    };

    # Server-optimized targets
    targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };

    # Optimize journal for servers
    extraConfig = ''
      DefaultTimeoutStopSec=10s
      DefaultTimeoutStartSec=10s
    '';
  };

  # Journald configuration for servers
  services.journald.extraConfig = ''
    SystemMaxUse=500M
    MaxRetentionSec=2weeks
    Compress=yes
    Seal=yes
    ForwardToSyslog=no
    ForwardToWall=no
  '';

  # Security hardening for servers
  security = {
    # Disable polkit for headless servers
    polkit.enable = lib.mkDefault false;

    # Enable sudo with wheel group
    sudo = {
      enable = true;
      wheelNeedsPassword = true;
      execWheelOnly = true;
    };

    # PAM configuration
    pam.services.sudo.requireWheel = true;

    # Login limits for performance
    pam.loginLimits = [
      {
        domain = "@users";
        item = "nofile";
        type = "-";
        value = "65536";
      }
      {
        domain = "@users";
        item = "nproc";
        type = "-";
        value = "32768";
      }
    ];
  };

  # Documentation settings for servers
  documentation = {
    enable = lib.mkDefault false;
    doc.enable = lib.mkDefault false;
    info.enable = lib.mkDefault false;
    man.enable = lib.mkDefault true; # Keep man pages
    nixos.enable = lib.mkDefault false;
  };

  # Automatic system maintenance
  system.autoUpgrade = {
    enable = vars.autoUpgrade.enable;
    allowReboot = vars.autoUpgrade.allowReboot;
    dates = vars.autoUpgrade.schedule;
    flake = "github:olafkfreund/nixos-config";
  };

  # Garbage collection for servers
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    # Optimize store regularly
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };

    settings = {
      # Build settings for servers
      max-jobs = "auto";
      cores = 0;

      # Experimental features
      experimental-features = [ "nix-command" "flakes" ];

      # Binary cache settings
      trusted-users = [ "root" vars.userName ];
      substituters = vars.nix.substituters;
      trusted-public-keys = vars.nix.trustedPublicKeys;
    };
  };

  # Age secrets configuration
  age.secrets = {
    "user-password-${vars.userName}" = {
      file = ../../secrets/user-password-${vars.userName}.age;
      owner = vars.userName;
      group = "users";
    };

    "user-password-root" = {
      file = ../../secrets/user-password-root.age;
      owner = "root";
      group = "root";
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
