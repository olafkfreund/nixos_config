{ config
, pkgs
, lib
, hostUsers
, ...
}:
let
  vars = import ./variables.nix;
in
{
  imports = [
    # Hardware and system configuration
    ./nixos/hardware-configuration.nix
    ./nixos/screens.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/${vars.gpu}.nix  # GPU-specific configuration
    ./nixos/usb-power-fix.nix # Fix USB issues (optional)
    ./nixos/i18n.nix
    ./nixos/hosts.nix
    ./nixos/envvar.nix
    ./nixos/greetd.nix
    ./nixos/cpu.nix
    ./nixos/memory.nix
    ./nixos/load.nix
    ./themes/stylix.nix

    # Modular imports
    ../../modules/core.nix
    ../../modules/development.nix
    ../../modules/desktop.nix
    ../../modules/virtualization.nix
    ../../modules/monitoring.nix
    ../../modules/performance.nix
    ../../modules/email.nix
    ../../modules/cloud.nix
    ../../modules/programs.nix
    ../../modules/development/default.nix
    ../common/hyprland.nix
    ../../modules/security/secrets.nix
    ../../modules/secrets/api-keys.nix
    ../../modules/containers/docker.nix
    ../../modules/scrcpy/default.nix
    ../../modules/system/logging.nix
  ];

  # Set hostname from variables
  networking.hostName = vars.hostName;

  # Choose networking profile: "desktop", "server", or "minimal"
  networking.profile = "desktop";

  # Tailscale VPN Configuration
  # Research shows acceptDns=false is critical for NixOS to avoid DNS conflicts  
  networking.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscale-auth-key.path;
    hostname = "${vars.hostName}-workstation";
    subnet = "192.168.1.0/24"; # Advertise local subnet
    acceptRoutes = true;
    acceptDns = false; # CRITICAL: Prevent Tailscale DNS conflicts with systemd-resolved
    ssh = true;
    shields = true;
    useRoutingFeatures = "client"; # Can route and accept routes
    extraUpFlags = [
      "--operator=${vars.username}"
      "--accept-risk=lose-ssh"
    ];
  };

  # Use systemd-resolved for proper DNS management with systemd-networkd
  # Based on Tailscale best practices research - avoid DNS conflicts
  services.resolved = {
    enable = true;
    fallbackDns = [ "192.168.1.222" "1.1.1.1" "8.8.8.8" ];
    domains = [ "~home.freundcloud.com" ]; # Use routing directive for local domain
    dnssec = lib.mkForce "false"; # Resolve DNSSEC conflict
    llmnr = lib.mkForce "false"; # Disable LLMNR to avoid conflicts with Tailscale
    extraConfig = ''
      DNS=192.168.1.222 1.1.1.1 8.8.8.8
      Domains=~home.freundcloud.com
      Cache=yes
      CacheFromLocalhost=no
      DNSStubListener=yes
      ReadEtcHosts=yes
    '';
  };

  # Configure AI providers (customize based on your needs)
  ai.providers = {
    enable = true;
    defaultProvider = "anthropic"; # or "openai", "gemini", "ollama"
    enableFallback = true;

    # Enable specific providers (customize as needed)
    openai.enable = true;
    anthropic.enable = true;
    gemini.enable = true;
    ollama.enable = true; # Set to false for lower resource usage
  };

  # AI-powered system analysis (optional but recommended)
  ai.analysis = {
    enable = true;
    aiProvider = "anthropic";
    enableFallback = true;

    features = {
      performanceAnalysis = true;
      resourceOptimization = true;
      configDriftDetection = true;
      predictiveMaintenance = true;
      logAnalysis = true;
      securityAnalysis = true;
    };

    # Analysis intervals
    intervals = {
      performanceAnalysis = "hourly";
      maintenanceAnalysis = "daily";
      configDriftCheck = "*:0/6";
      logAnalysis = "*:0/4";
    };

    # Conservative automation for workstation
    automation = {
      autoApplyOptimizations = false; # Keep disabled for safety
      autoCorrectDrift = false; # Keep disabled for safety
      generateReports = true;
    };
  };

  # Memory optimization
  ai.memoryOptimization = {
    enable = true;
    autoOptimize = true;
    nixStoreOptimization = true;
    logRotation = true;

    thresholds = {
      memoryWarning = 75;
      memoryCritical = 85;
      diskWarning = 75;
      diskCritical = 85;
    };
  };

  # SSH security hardening
  security.sshHardening = {
    enable = true;
    allowedUsers = hostUsers;
    allowPasswordAuthentication = false;
    allowRootLogin = false;
    maxAuthTries = 3;
    enableFail2Ban = true;
    enableKeyOnlyAccess = true;
    trustedNetworks = [ "192.168.1.0/24" "10.0.0.0/8" ];
  };

  # Hardware monitoring with desktop notifications
  monitoring.hardwareMonitor = {
    enable = true;
    interval = 300; # Check every 5 minutes
    enableDesktopNotifications = true;

    criticalThresholds = {
      diskUsage = 85;
      memoryUsage = 90;
      cpuLoad = 200; # Adjust based on your CPU cores
      temperature = 85;
    };

    warningThresholds = {
      diskUsage = 75;
      memoryUsage = 80;
      cpuLoad = 150;
      temperature = 75;
    };
  };

  # Use the comprehensive features system
  features = {
    development = {
      enable = true;
      ansible = true;
      cargo = true;
      github = true;
      go = true;
      java = true;
      lua = true;
      nix = true;
      shell = true;
      python = true;
      nodejs = true;
    };

    virtualization = {
      enable = true;
      docker = true;
      incus = false;
      podman = true;
      spice = true;
      libvirt = true;
      sunshine = true;
    };

    cloud = {
      enable = true;
      aws = true;
      azure = true;
      google = true;
      k8s = true;
      terraform = true;
    };

    security = {
      enable = true;
      onepassword = true;
      gnupg = true;
    };

    networking = {
      enable = true;
    };

    ai = {
      enable = true;
      ollama = true; # Set to false for lower resource usage
      gemini-cli = true;

      # Enable unified AI provider support
      providers = {
        enable = true;
        defaultProvider = "anthropic"; # Customize your preferred provider
        enableFallback = true;

        # Enable providers based on your API access
        openai.enable = true;
        anthropic.enable = true;
        gemini.enable = true;
        ollama.enable = true;
      };
    };

    email = {
      enable = true;
      neomutt.enable = true;
      ai.enable = true;
      ai.provider = "anthropic";
      notifications.enable = true;
      notifications.highPriorityOnly = true;
    };

    programs = {
      lazygit = true;
      thunderbird = true;
      obsidian = true;
      office = true;
      webcam = true;
      print = true;
    };

    media = {
      droidcam = true;
    };

    # Gaming support (optional - set to false if not needed)
    gaming = {
      enable = true; # Set to false for work-focused systems
      steam = true;
      lutris = true;
      gamemode = true;
    };
  };

  # Monitoring configuration - client mode (sends data to monitoring server)
  monitoring = {
    enable = true;
    mode = "client"; # Send data to monitoring server
    serverHost = "dex5550"; # Change to your monitoring server hostname

    features = {
      nodeExporter = true;
      nixosMetrics = true;
      alerting = false; # Only server handles alerting
      logging = true; # Enable Promtail for log collection
      prometheus = false; # Only server runs Prometheus
      grafana = false; # Only server runs Grafana
      # GPU metrics - enable based on your GPU type
      amdGpuMetrics = lib.mkIf (vars.gpu == "amd") true;
      nvidiaGpuMetrics = lib.mkIf (vars.gpu == "nvidia") true;
      aiMetrics = true; # Enable AI metrics collection
    };

    # Enable AI metrics exporter
    aiMetricsExporter = {
      enable = true;
      port = 9105;
      interval = "30s";
      dataDir = "/var/lib/ai-analysis";
    };
  };

  # Centralized Logging - Send logs to monitoring server
  services.promtail-logging = {
    enable = true;
    lokiUrl = "http://dex5550:3100"; # Change to your monitoring server
    collectJournal = true;
    collectKernel = true;
  };

  # Enable encrypted API keys
  secrets.apiKeys = {
    enable = true;
    enableEnvironmentVariables = true;
    enableUserEnvironment = true;
  };

  # Enable logging configuration for noise reduction
  system.logging = {
    enableFiltering = true;
    filterRules = [
      "router dispatching GET /health"
      "router jsonParser  : /health"
      "body-parser:json skip empty body"
      "GET /health"
      "health check"
      "connection established"
      "connection closed"
    ];
  };

  # Android connectivity (optional)
  scrcpyWifi.enable = true;

  # Temperature dashboard script
  scripts.tempDashboard.enable = true;

  # AI Ollama-specific configuration
  ai.ollama = {
    enableRag = false; # Can be enabled if needed
    ragDirectory = "/home/${vars.username}/documents/rag-files";
    allowBrokenPackages = false;
  };

  # Enable Hyprland system configuration
  modules.desktop.hyprland-uwsm.enable = true;

  # Docker configuration
  modules.containers.docker = {
    enable = true;
    users = hostUsers;
    rootless = false;
  };

  # Enable secrets management
  modules.security.secrets = {
    enable = true;
    hostKeys = [ "/etc/ssh/ssh_host_ed25519_key" ];
    userKeys = [ "/home/${vars.username}/.ssh/id_ed25519" ];
  };

  # Create system users for all host users
  users.users = lib.genAttrs hostUsers (username: {
    isNormalUser = true;
    description = "User ${username}";
    extraGroups = [ "wheel" "networkmanager" "render" "docker" ];
    shell = pkgs.zsh;
    # Only use secret-managed password if the secret exists
    hashedPasswordFile =
      lib.mkIf
        (config.modules.security.secrets.enable
          && builtins.hasAttr "user-password-${username}" config.age.secrets)
        config.age.secrets."user-password-${username}".path;
  });

  # Service-specific configurations
  services = {
    xserver = {
      enable = true;
      displayManager.xserverArgs = [
        "-nolisten tcp"
        "-dpi 96"
      ];
      videoDrivers = [ "${vars.gpu}gpu" ]; # Set video driver based on GPU
    };

    # Desktop environment
    desktopManager.gnome.enable = true;

    # File systems and services (optional)
    nfs.server = lib.mkIf (vars.services.nfs.enable or false) {
      enable = true;
      exports = vars.services.nfs.exports or "";
    };

    # Other services
    playerctld.enable = true;
    fwupd.enable = true;

    # ClamAV antivirus (optional)
    clamav = {
      daemon.enable = true;
      updater.enable = true;
    };

    # Ollama specific configurations based on GPU type
    ollama = lib.mkIf (vars.gpu != "none") {
      enable = true;
      acceleration = lib.mkForce vars.acceleration;
      environmentVariables =
        if vars.gpu == "amd" then {
          HCC_AMDGPU_TARGET = lib.mkForce "gfx1100";
          ROC_ENABLE_PRE_VEGA = lib.mkForce "1";
          HSA_OVERRIDE_GFX_VERSION = lib.mkForce "11.0.0";
        } else if vars.gpu == "nvidia" then {
          CUDA_VISIBLE_DEVICES = lib.mkForce "0";
        } else { };
    };
  };

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    curl
    wget
    # Add GPU-specific packages
  ] ++ lib.optionals (vars.gpu == "amd") [
    rocmPackages.llvm.libcxx
  ] ++ lib.optionals (vars.gpu == "nvidia") [
    nvtopPackages.nvidia
  ];

  # Hardware-specific configurations
  hardware = {
    keyboard.qmk.enable = true;
    flipperzero.enable = lib.mkDefault false; # Enable if you have one
  };

  # Network-specific overrides that go beyond the network profile
  systemd.network.wait-online.timeout = 10;
  systemd.services = {
    NetworkManager-wait-online.enable = lib.mkForce false;
    systemd-networkd-wait-online.enable = lib.mkForce false;
    fwupd.serviceConfig.LimitNOFILE = 524288;
  };

  # Use DHCP-provided DNS and standard networking
  networking = {
    useNetworkd = lib.mkForce true;
  };

  # Configure systemd-networkd for your network interfaces
  systemd.network = {
    enable = true;
    networks = {
      "20-wired" = {
        matchConfig.Name = "en*";
        networkConfig = {
          MulticastDNS = false;
          LLMNR = false;
          DHCP = "ipv4";
          IPv6AcceptRA = true;
          Domains = "~home.freundcloud.com"; # Use routing directive for local domain
          DNS = [ "192.168.1.222" "1.1.1.1" "8.8.8.8" ];
        };
        # Higher priority for wired connection
        dhcpV4Config = {
          RouteMetric = 10;
          UseDNS = false; # Use our custom DNS configuration
        };
      };
      "25-wireless" = {
        matchConfig.Name = "wl*";
        networkConfig = {
          MulticastDNS = false;
          LLMNR = false;
          DHCP = "ipv4";
          IPv6AcceptRA = true;
        };
        # Lower priority for wireless
        dhcpV4Config = {
          RouteMetric = 20;
        };
      };
      # Configure Tailscale interface - CRITICAL: Don't let systemd-networkd manage it
      # Research shows this prevents "Link tailscale0 is managed" DNS conflicts
      "30-tailscale" = {
        matchConfig.Name = "tailscale0";
        networkConfig = {
          MulticastDNS = false;
          LLMNR = false;
          DHCP = "no"; # NEVER enable DHCP on Tailscale interface
          DNS = [ ]; # Explicitly no DNS - let Tailscale handle it
          Domains = [ ]; # No domain routing through this interface
        };
      };
    };
  };

  # Performance Optimization Configuration
  # High-performance workstation profile
  system.resourceManager = {
    enable = true;
    profile = "performance"; # Options: "performance", "balanced", "efficiency"

    cpuManagement = {
      enable = true;
      dynamicGovernor = true;
      affinityOptimization = true;
      coreReservation = false; # Use all cores for maximum performance
    };

    memoryManagement = {
      enable = true;
      dynamicSwap = true;
      hugePagesOptimization = true;
      memoryCompression = false; # Disable for performance
      oomProtection = true;
    };

    ioManagement = {
      enable = true;
      dynamicScheduler = true;
      ioNiceOptimization = true;
      cacheOptimization = true;
    };

    networkManagement = {
      enable = true;
      trafficShaping = false;
      connectionOptimization = true;
    };
  };

  # Network performance tuning
  networking.performanceTuning = {
    enable = true;
    profile = "balanced"; # Options: "throughput", "latency", "balanced"

    tcpOptimization = {
      enable = true;
      congestionControl = "bbr";
      windowScaling = true;
      fastOpen = true;
      lowLatency = false; # Set to true for gaming/real-time apps
    };

    bufferOptimization = {
      enable = true;
      receiveBuffer = 16777216; # 16MB
      sendBuffer = 16777216; # 16MB
      autotuning = true;
    };

    interHostOptimization = {
      enable = true;
      hosts = [ "dex5550" "p510" "razer" ]; # Your other hosts
      jumboFrames = false; # Keep disabled for compatibility
      routeOptimization = true;
    };

    dnsOptimization = {
      enable = true;
      caching = true;
      parallelQueries = true;
      customServers = [ "192.168.1.222" "1.1.1.1" ];
    };
  };

  # Storage performance optimization
  storage.performanceOptimization = {
    enable = true;
    profile = "performance"; # Options: "performance", "balanced", "capacity"

    ioSchedulerOptimization = {
      enable = true;
      dynamicScheduling = true;
      ssdOptimization = true;
      hddOptimization = true;
    };

    filesystemOptimization = {
      enable = true;
      readaheadOptimization = true;
      cacheOptimization = true;
      compressionOptimization = false; # Disable for performance
    };

    nvmeOptimization = {
      enable = true;
      queueDepth = 64; # High queue depth for performance
      polling = true;
      multiQueue = true;
    };

    tmpfsOptimization = {
      enable = true;
      tmpSize = "8G"; # Adjust based on your RAM
      varTmpSize = "2G";
      devShmSize = "50%";
    };
  };

  # Package configurations
  nixpkgs.config = {
    allowBroken = true;
    permittedInsecurePackages = [
      "olm-3.2.16"
      "python3.12-youtube-dl-2021.12.17"
    ];
  };

  # System version
  system.stateVersion = "25.11";
}
