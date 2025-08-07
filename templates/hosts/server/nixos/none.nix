# No GPU / Headless configuration for server template
# Optimized for pure headless server operation without any GPU
{ pkgs, lib, ... }:

{
  # Minimal graphics support for headless servers
  hardware.graphics = {
    enable = false; # Completely disable graphics subsystem
  };

  # Server-focused system packages (no GPU tools)
  environment.systemPackages = with pkgs; [
    # Essential system administration
    htop
    iotop
    nethogs
    lm_sensors
    smartmontools

    # Hardware diagnostics (no GPU tools)
    pciutils # lspci
    usbutils # lsusb
    lshw # Hardware listing
    dmidecode # Hardware information

    # Network monitoring
    iftop # Network bandwidth
    mtr # Network diagnostics
    tcpdump # Packet capture

    # System monitoring
    sysstat # System statistics
    lsof # Open files
    strace # System call tracing

    # Process management
    psmisc # killall, pstree, etc.
    procps # ps, top, etc.

    # Storage tools
    parted # Disk partitioning
    gptfdisk # GPT partitioning
    cryptsetup # Disk encryption

    # Backup and archiving
    borgbackup # Deduplicating backup
    rsync # File synchronization
    rclone # Cloud storage sync

    # Security tools
    fail2ban # Intrusion prevention
    rkhunter # Rootkit hunter
    chkrootkit # Rootkit detection

    # Remote access (no VNC)
    openssh # SSH client
    mosh # Mobile shell

    # Text processing
    jq # JSON processor
    yq # YAML processor
    xmlstarlet # XML processor
  ];

  # Environment variables for headless operation
  environment.variables = {
    # Force software rendering if needed
    LIBGL_ALWAYS_SOFTWARE = "1";
    GALLIUM_DRIVER = "llvmpipe";

    # Terminal-focused environment
    TERM = "xterm-256color";

    # Disable all GPU-related variables
    GPU_MAX_ALLOC_PERCENT = "";
    GPU_USE_SYNC_OBJECTS = "";
    AMD_VULKAN_ICD = "";
    NVIDIA_DRIVER_CAPABILITIES = "";

    # Console-only configuration
    DISPLAY = "";
    WAYLAND_DISPLAY = "";
    XDG_SESSION_TYPE = "tty";
  };

  # No GPU kernel modules
  boot.kernelModules = [ ];

  # Server-optimized kernel parameters
  boot.kernelParams = [
    "nomodeset" # Disable all kernel modesetting
    "vga=normal" # Use basic VGA text mode
    "quiet" # Quiet boot for servers
    "loglevel=3" # Reduce boot messages
    "systemd.show_status=auto"
    "rd.udev.log_level=3"

    # Disable graphics-related features
    "video=efifb:off" # Disable EFI framebuffer
    "i915.modeset=0" # Disable Intel graphics
    "radeon.modeset=0" # Disable AMD graphics
    "nouveau.modeset=0" # Disable Nouveau
  ];

  # Server-optimized kernel configuration
  boot.kernel.sysctl = {
    # Network performance for servers
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_max" = 134217728;
    "net.ipv4.tcp_rmem" = "4096 65536 134217728";
    "net.ipv4.tcp_wmem" = "4096 65536 134217728";
    "net.ipv4.tcp_congestion_control" = "bbr";

    # Memory management for servers
    "vm.swappiness" = 1; # Minimize swap usage
    "vm.dirty_ratio" = 10; # Conservative disk I/O
    "vm.dirty_background_ratio" = 5;
    "vm.vfs_cache_pressure" = 50;

    # Security hardening
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.printk" = "3 3 3 3"; # Reduce kernel messages
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;
    "dev.tty.ldisc_autoload" = 0;
    "vm.unprivileged_userfaultfd" = 0;
    "kernel.kexec_load_disabled" = 1;
    "kernel.sysrq" = 0;
    "kernel.unprivileged_userns_clone" = 0;
    "kernel.perf_event_paranoid" = 3;

    # Network security
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
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
  };

  # No GPU-specific udev rules
  services.udev.extraRules = ''
    # Basic device permissions for servers
    KERNEL=="tty*", GROUP="tty", MODE="0664"
    KERNEL=="console", GROUP="tty", MODE="0664"

    # Serial device permissions
    KERNEL=="ttyS*", GROUP="dialout", MODE="0664"

    # Block device permissions
    KERNEL=="sd*", GROUP="disk", MODE="0664"
    KERNEL=="nvme*", GROUP="disk", MODE="0664"
  '';

  # Power management optimized for efficiency
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "powersave"; # Maximum power efficiency
    powertop.enable = true; # Power optimization
  };

  # Completely disable gaming and multimedia
  programs.gamemode.enable = lib.mkForce false;
  programs.steam.enable = lib.mkForce false;

  # Disable all audio for headless servers
  services.pipewire.enable = lib.mkForce false;
  hardware.pulseaudio.enable = lib.mkForce false;
  sound.enable = lib.mkForce false;
  services.alsa.enable = lib.mkForce false;

  # Disable all desktop and display-related services
  services.xserver.enable = lib.mkForce false;
  services.displayManager.gdm.enable = lib.mkForce false;
  services.desktopManager.gnome.enable = lib.mkForce false;
  programs.hyprland.enable = lib.mkForce false;
  programs.sway.enable = lib.mkForce false;
  services.xrdp.enable = lib.mkForce false;

  # Minimal hardware support
  hardware = {
    # Disable GPU-specific features
    enableAllFirmware = lib.mkDefault false;
    enableRedistributableFirmware = lib.mkDefault true; # Keep for network/storage

    # Disable unnecessary hardware
    bluetooth.enable = lib.mkForce false;
    pulseaudio.enable = lib.mkForce false;

    # Graphics completely disabled
    graphics.enable = lib.mkForce false;
  };

  # Console-only configuration
  console = {
    enable = true;
    font = "Lat2-Terminus16";
    useXkbConfig = false; # No X11 keyboard config needed
    packages = with pkgs; [ terminus_font ];
  };

  # Network configuration optimized for servers
  networking = {
    # Use networkd for server-style networking
    useNetworkd = lib.mkDefault true;
    dhcpcd.enable = lib.mkDefault false; # Use systemd-networkd instead

    # Minimal network configuration
    usePredictableInterfaceNames = true;

    # Enable IPv6
    enableIPv6 = true;
  };

  # Server-optimized systemd network configuration
  systemd.network = {
    enable = true;
    wait-online = {
      enable = false; # Don't wait for network on servers
    };
    networks = {
      "20-wired" = {
        matchConfig.Name = "en* eth*";
        networkConfig = {
          DHCP = "ipv4";
          IPv6AcceptRA = true;
          MulticastDNS = false; # Disable for servers
          LLMNR = false; # Disable for servers
          LinkLocalAddressing = "ipv6";
        };
        dhcpV4Config = {
          RouteMetric = 10;
          UseDNS = true;
          UseRoutes = true;
        };
      };
    };
  };

  # SSH configuration optimized for servers
  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
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
      MaxSessions = 10;
      MaxStartups = "10:30:100";
    };
    openFirewall = true;
    ports = [ 22 ];
    banner = "Authorized access only. All activity monitored.";
  };

  # Strict firewall configuration for servers
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ]; # SSH only by default
    allowedUDPPorts = [ ];

    # Strict firewall settings
    allowPing = true;
    logReversePathDrops = true;
    logRefusedConnections = false; # Reduce log spam
    logRefusedPackets = false; # Reduce log spam

    # Extra security rules
    extraCommands = ''
      # Rate limit SSH connections
      iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set --name SSH
      iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --rttl --name SSH -j DROP

      # Drop invalid packets
      iptables -A INPUT -m state --state INVALID -j DROP

      # Rate limit ping requests
      iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/second -j ACCEPT
    '';
  };

  # Completely minimal font configuration
  fonts = {
    enableDefaultPackages = false; # Disable all GUI fonts
    packages = with pkgs; [
      # Only console fonts
      terminus_font
    ];
    fontconfig.enable = lib.mkForce false; # Disable fontconfig
  };

  # Disable all unnecessary systemd services
  systemd.services = {
    # Disable desktop-related services
    NetworkManager-wait-online.enable = lib.mkForce false;
    systemd-networkd-wait-online.enable = lib.mkForce false;
    accounts-daemon.enable = lib.mkForce false;
    rtkit-daemon.enable = lib.mkForce false;
    alsa-state.enable = lib.mkForce false;
    udisks2.enable = lib.mkForce false;

    # Keep essential services only
    sshd.enable = lib.mkDefault true;
    fail2ban.enable = lib.mkDefault true;
  };

  # Disable all unnecessary systemd targets
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
    graphical-session.enable = lib.mkForce false;
  };

  # Minimal system packages for headless servers
  environment.systemPackages = lib.mkForce (with pkgs; [
    # Essential command-line tools only
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
    iperf3 # Network performance
    mtr # Network diagnostics
    nmap # Network scanner

    # System administration
    pciutils # lspci
    usbutils # lsusb
    util-linux # Various utilities
    procps # ps, top, etc.
    sysstat # System statistics
    lm_sensors # Hardware sensors
    smartmontools # Disk health

    # Security
    fail2ban
    rkhunter
    chkrootkit

    # Monitoring
    nethogs # Network usage per process
    iftop # Network bandwidth usage

    # File management
    findutils # find, locate, etc.
    coreutils # Basic utilities
    diffutils # diff, cmp, etc.

    # Text processing
    gnugrep # grep
    gnused # sed
    gawk # awk
    less # pager

    # Compression
    bzip2
    xz
    zstd
  ]);

  # Systemd user services disabled
  systemd.user.services = { };
  systemd.user.targets.default.enable = lib.mkForce false;

  # Optimized logging configuration for servers
  services.journald.extraConfig = ''
    SystemMaxUse=200M
    MaxRetentionSec=2weeks
    Compress=yes
    Seal=yes
    ForwardToSyslog=no
    ForwardToWall=no
    ForwardToConsole=no
  '';

  # Disable all documentation to save space
  documentation = {
    enable = lib.mkDefault false;
    doc.enable = lib.mkDefault false;
    info.enable = lib.mkDefault false;
    man.enable = lib.mkDefault true; # Keep man pages
    nixos.enable = lib.mkDefault false;
  };

  # Security configuration for headless servers
  security = {
    # Disable GUI security features
    polkit.enable = lib.mkDefault false;
    rtkit.enable = lib.mkForce false;

    # Enable essential security
    sudo.enable = true;
    pam.services.sudo.requireWheel = true;

    # Login limits for server performance
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
      {
        domain = "root";
        item = "nofile";
        type = "-";
        value = "1048576";
      }
    ];
  };

  # Disable all virtualization GUI tools
  virtualisation = {
    # Keep container support but disable GUI
    docker.enable = lib.mkDefault false;
    podman.enable = lib.mkDefault false;

    # Completely disable desktop virtualization
    libvirtd.enable = lib.mkDefault false;
    virtualbox.host.enable = lib.mkForce false;
    vmware.host.enable = lib.mkForce false;
  };

  # Server performance tuning
  boot.kernel.sysctl = lib.mkMerge [
    {
      # File system performance
      "fs.file-max" = 2097152;
      "fs.nr_open" = 1048576;

      # Process limits
      "kernel.pid_max" = 4194304;
      "kernel.threads-max" = 1048576;

      # Memory management
      "vm.max_map_count" = 262144;
      "vm.min_free_kbytes" = 65536;
    }
  ];
}
