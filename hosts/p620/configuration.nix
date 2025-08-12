{ config
, pkgs
, lib
, hostUsers
, hostTypes
, ...
}:
let
  vars = import ./variables.nix { inherit lib; };
in
{
  # Use workstation template and add P620-specific modules
  imports = hostTypes.workstation.imports ++ [
    # Hardware-specific imports
    ./nixos/hardware-configuration.nix
    ./nixos/screens.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/amd.nix
    ./nixos/usb-power-fix.nix # Fix USB mouse freezing issues
    ../common/nixos/i18n.nix
    ../common/nixos/hosts.nix
    ../common/nixos/envvar.nix
    ./nixos/greetd.nix
    ./nixos/cpu.nix
    ./nixos/memory.nix
    ./nixos/load.nix
    ./themes/stylix.nix

    # P620-specific additional modules
    ../../modules/development/default.nix
    ../common/hyprland.nix
    ../../modules/security/secrets.nix
    ../../modules/secrets/api-keys.nix
    ../../modules/containers/docker.nix
    ../../modules/scrcpy/default.nix
    ../../modules/system/logging.nix
  ];
  # Consolidated networking configuration
  networking = {
    # Set hostname from variables
    inherit (vars) hostName;

    # Choose networking profile: "desktop", "server", or "minimal"
    profile = "server";

    tailscale = {
      enable = true;
      authKeyFile = config.age.secrets.tailscale-auth-key.path;
      hostname = "p620-workstation";
      subnet = "192.168.1.0/24"; # Advertise local subnet
      acceptRoutes = true;
      acceptDns = false; # CRITICAL: Prevent Tailscale DNS conflicts with systemd-resolved
      ssh = true;
      shields = true;
      useRoutingFeatures = "both"; # Can route and accept routes
      extraUpFlags = [
        "--operator=olafkfreund"
        "--accept-risk=lose-ssh"
      ];
    };

    # Use DHCP-provided DNS and standard networking
    useNetworkd = lib.mkForce true;

    # Network performance tuning
    performanceTuning = {
      enable = true;
      profile = "throughput"; # Optimize for AI workload throughput

      tcpOptimization = {
        enable = true;
        congestionControl = "bbr";
        windowScaling = true;
        fastOpen = true;
        lowLatency = false; # Prioritize throughput over latency
      };

      bufferOptimization = {
        enable = true;
        receiveBuffer = 33554432; # 32MB for high-throughput AI workloads
        sendBuffer = 33554432; # 32MB for high-throughput AI workloads
        autotuning = true;
      };

      interHostOptimization = {
        enable = true;
        hosts = [ "dex5550" "p510" "razer" ];
        jumboFrames = false; # Keep disabled for compatibility
        routeOptimization = true;
      };

      dnsOptimization = {
        enable = true;
        caching = true;
        parallelQueries = true;
        customServers = [ "192.168.1.222" "1.1.1.1" ];
      };

      monitoringOptimization = {
        enable = true;
        compression = true;
        batchingInterval = 5; # More frequent for performance workstation
        prioritization = true;
      };
    };

    # Firewall configuration for SSH
    firewall = {
      allowedTCPPorts = [ 22 ]; # SSH port from hardening config

      # Extra rules for SSH protection
      extraCommands = ''
        # Rate limiting for SSH connections
        iptables -I INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set --name SSH_LIMIT
        iptables -I INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 --name SSH_LIMIT -j DROP

        # Allow established SSH connections
        iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

        # Log dropped SSH attempts
        iptables -A INPUT -p tcp --dport 22 -j LOG --log-prefix "SSH-DROP: " --log-level 4
      '';

      extraStopCommands = ''
        # Clean up SSH rules
        iptables -D INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set --name SSH_LIMIT 2>/dev/null || true
        iptables -D INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 --name SSH_LIMIT -j DROP 2>/dev/null || true
      '';
    };
  };

  # Use AI provider defaults with workstation profile
  aiDefaults = {
    enable = true;
    profile = "workstation";
  };
  # P620-specific override: use OpenAI as default instead of Anthropic
  ai.providers.defaultProvider = "openai";

  # AI analysis services removed - were non-functional and consuming resources
  # ai.analysis = {
  #   enable = false;  # Removed completely - provided no meaningful analysis
  #   aiProvider = "openai";
  # };

  # AI memory optimization and automated remediation removed - were non-functional and consuming resources

  # Non-functional AI modules removed - were consuming resources without providing value
  # ai.storageAnalysis = {
  #   enable = false;  # Removed - no meaningful analysis output
  # };
  # ai.securityAudit = {
  #   enable = false;  # Removed - no actual audits performed
  # };
  # ai.systemValidation = {
  #   enable = false;  # Removed - no validation functionality
  # };
  # ai.performanceOptimization = {
  #   enable = false;  # Removed - no actual optimizations applied
  # };

  # Enable SSH security hardening
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

  # AI production dashboard and load testing removed - were non-functional services consuming resources

  # Enable NixOS package monitoring tools
  tools.nixpkgs-monitors = {
    enable = true;
    installAll = true;
  };

  # AI alerting removed - was non-functional, handled by DEX5550 monitoring server via Prometheus/Grafana/Alertmanager

  # Use the new features system instead of multiple lib.mkForce calls
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
      devshell = true; # Temporarily disabled due to patch issue
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
      ollama = true;
      gemini-cli = true;

      # Enable unified AI provider support
      providers = {
        enable = true;
        defaultProvider = "openai";
        enableFallback = true;

        # Enable specific providers
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
      ai.provider = "openai";
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

    # Enable QuickShell for testing (experimental - runs alongside Waybar)
    quickshell = {
      enable = true;
    };
  };

  # Consolidated monitoring configuration
  monitoring = {
    enable = true;
    mode = "client"; # Send data to dex5550 monitoring server
    serverHost = "dex5550";

    features = {
      nodeExporter = true;
      nixosMetrics = true;
      alerting = false; # Only server handles alerting
      logging = true; # Enable Promtail for log collection
      prometheus = false; # Only server runs Prometheus
      grafana = false; # Only server runs Grafana
      amdGpuMetrics = true; # Enable AMD GPU monitoring for P620
      aiMetrics = true; # Enable AI metrics collection
    };

    # Enable AI metrics exporter
    aiMetricsExporter = {
      enable = true;
      port = 9105;
      interval = "30s";
      dataDir = "/var/lib/ai-analysis";
    };

    # Enable hardware monitoring with desktop notifications
    hardwareMonitor = {
      enable = true;
      interval = 300; # Check every 5 minutes
      enableDesktopNotifications = true;

      criticalThresholds = {
        diskUsage = 85; # P620 at 49.6%, lower threshold for early warning
        memoryUsage = 90; # P620 at 22.8%, higher threshold OK for workstation
        cpuLoad = 200; # AMD Ryzen 5 PRO 4650G (12 cores)
        temperature = 85; # AMD CPU, conservative threshold
      };

      warningThresholds = {
        diskUsage = 75; # Early warning for P620
        memoryUsage = 80; # Memory warning
        cpuLoad = 150; # Load warning
        temperature = 75; # Temperature warning
      };
    };

    # Performance analytics
    performanceAnalytics = {
      enable = true;
      dataRetention = "30d";
      analysisInterval = "1m"; # Frequent analysis for performance workstation

      metricsCollection = {
        enable = true;
        systemMetrics = true;
        applicationMetrics = true;
        networkMetrics = true;
        storageMetrics = true;
        aiMetrics = true;
      };

      analytics = {
        enable = true;
        trendAnalysis = true;
        anomalyDetection = true;
        predictiveAnalysis = true;
        bottleneckDetection = true;
      };

      reporting = {
        enable = true;
        dailyReports = true;
        weeklyReports = true;
        alertThresholds = true;
      };

      dashboards = {
        enable = true;
        realTimeMetrics = true;
        historicalAnalysis = true;
        customMetrics = true;
      };
    };
  };

  # Enable encrypted API keys

  secrets.apiKeys = {
    enable = true;
    enableEnvironmentVariables = true;
    enableUserEnvironment = true;
  };

  # Consolidated system configuration
  system = {
    # Enable logging configuration for noise reduction
    logging = {
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

    # Performance Optimization Configuration (Phase 10.4)
    # High-performance AMD workstation profile
    resourceManager = {
      enable = true;
      profile = "performance";

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

    # System version
    stateVersion = "25.11";
  };

  scrcpyWifi.enable = true;

  # Temperature dashboard script
  scripts.tempDashboard.enable = true;

  # Advanced CPU monitoring script for Waybar
  scripts.cpuAdvanced.enable = true;

  # AI Ollama-specific configuration that goes beyond simple enabling
  ai.ollama = {
    enableRag = false; # Temporarily disabled due to ChromaDB 1.0.12 startup bug
    ragDirectory = "/home/${vars.username}/documents/rag-files";
    allowBrokenPackages = false;
  };

  # Consolidated modules configuration
  modules = {
    # Enable Hyprland system configuration
    desktop.hyprland-uwsm.enable = true;

    # Docker configuration
    containers.docker = {
      enable = true;
      users = hostUsers; # Use all users for this host
      rootless = false;
    };

    # Enable secrets management
    security.secrets = {
      enable = true;
      userKeys = [ "/home/${vars.username}/.ssh/id_ed25519" ];
    };
  };

  # Create system users for all host users
  users.users = lib.genAttrs hostUsers (username: {
    isNormalUser = true;
    description = "User ${username}";
    extraGroups = [ "wheel" "networkmanager" "render" ];
    shell = pkgs.zsh;
    # Only use secret-managed password if the secret exists
    hashedPasswordFile =
      lib.mkIf
        (config.modules.security.secrets.enable
          && builtins.hasAttr "user-password-${username}" config.age.secrets)
        config.age.secrets."user-password-${username}".path;
  });

  # Remove duplicate user configuration - use the one above that handles all hostUsers
  # users.users.${vars.username} is now handled by the genAttrs above

  # Consolidated services configuration
  services = {
    # Nixai
    nixai = {
      enable = true;
      mcp.enable = true;
    };

    # Use systemd-resolved for proper DNS management with systemd-networkd
    # Based on Tailscale best practices research - avoid DNS conflicts
    resolved = {
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

    # X server configuration
    xserver = {
      enable = true;
      displayManager.xserverArgs = [
        "-nolisten tcp"
        "-dpi 96"
      ];
      videoDrivers = [ "${vars.gpu}gpu" ]; # Correct way to set the video driver
    };

    # Desktop environment
    desktopManager.gnome.enable = true;

    # File systems and services
    nfs.server = lib.mkIf vars.services.nfs.enable {
      enable = true;
      inherit (vars.services.nfs) exports;
    };

    # Other services
    playerctld.enable = true;
    fwupd.enable = true;

    # ClamAV configuration
    clamav = {
      daemon.enable = true; # Enable clamd (ClamAV daemon)
      updater.enable = true; # Enable freshclam (virus database updater)
    };

    # Nix-serve configuration
    nix-serve = {
      enable = true;
      port = 5000; # Default port for nix-serve
      secretKeyFile = "/etc/nix/secret-key"; # Path to the secret key file
      openFirewall = true; # Automatically open the firewall port
    };

    # Ollama specific configurations for AMD GPU
    ollama = {
      enable = true;
      acceleration = lib.mkForce vars.acceleration;
      rocmOverrideGfx = lib.mkForce "11.0.0";
      environmentVariables = {
        HCC_AMDGPU_TARGET = lib.mkForce "gfx1100";
        ROC_ENABLE_PRE_VEGA = lib.mkForce "1";
        HSA_OVERRIDE_GFX_VERSION = lib.mkForce "11.0.0";
      };
    };

    # Centralized Logging - Send logs to DEX5550 Loki server
    promtail-logging = {
      enable = true;
      lokiUrl = "http://dex5550:3100";
      collectJournal = true;
      collectKernel = true;
    };

    # Hardware-specific configurations
    udev = {
      packages = [ pkgs.via ];
      extraRules = builtins.concatStringsSep "\n" [
        ''ACTION=="add", SUBSYSTEM=="video4linux", DRIVERS=="uvcvideo", RUN+="${pkgs.v4l-utils}/bin/v4l2-ctl --set-ctrl=power_line_frequency=1"''
        ''KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", TAG+="uaccess"''
      ];
    };
  };

  # System packages
  environment.systemPackages = with pkgs; [
    rocmPackages.llvm.libcxx
    via
    looking-glass-client
    scream
    vim
    wally-cli
    # Qt theme control tools for Stylix
    libsForQt5.qt5ct
    kdePackages.qt6ct
    # Custom qwen-code package
    (callPackage ../../home/development/qwen-code/default.nix { })
  ];

  # Hardware features
  hardware = {
    keyboard.qmk.enable = true;
    flipperzero.enable = true;
  };

  # File systems
  fileSystems."/mnt/media" = {
    device = "192.168.1.127:/mnt/media";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" ];
  };

  # Consolidated systemd configuration
  systemd = {
    # Network-specific overrides that go beyond the network profile
    network = {
      enable = true;
      wait-online.timeout = 10;
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

    services = {
      NetworkManager-wait-online.enable = lib.mkForce false;
      systemd-networkd-wait-online.enable = lib.mkForce false;
      fwupd.serviceConfig.LimitNOFILE = 524288;
    };

    # User services
    user.services.scream-ivshmem = {
      enable = true;
      description = "Scream IVSHMEM";
      serviceConfig = {
        ExecStart = "${pkgs.scream}/bin/scream-ivshmem-pulse /dev/shm/scream";
        Restart = "always";
      };
      wantedBy = [ "multi-user.target" ];
      requires = [ "pulseaudio.service" ];
    };
  };

  # Nix configuration
  nix.settings.allowed-users = [ "nix-serve" ];

  # Storage performance optimization
  storage.performanceOptimization = {
    enable = true;
    profile = "performance";

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

    diskCacheOptimization = {
      enable = true;
      writeCache = true;
      readCache = true;
      barrierOptimization = false; # Keep safe
    };

    tmpfsOptimization = {
      enable = true;
      tmpSize = "16G"; # Large temp space for AI workloads and complex builds
      varTmpSize = "2G";
      devShmSize = "50%";
    };
  };

  # AI-powered automated performance tuning removed - was non-functional and consuming resources

  # Agenix identity configuration - specify where to find decryption keys
  age.identityPaths = [
    "/home/olafkfreund/.ssh/id_ed25519" # User key
    "/etc/ssh/ssh_host_ed25519_key" # Host key (Ed25519)
    "/etc/ssh/ssh_host_rsa_key" # Host key (RSA fallback)
  ];

  # Package configurations
  nixpkgs.config = {
    allowBroken = true;
    permittedInsecurePackages = [
      "olm-3.2.16"
      "python3.12-youtube-dl-2021.12.17"
    ];
  };
}
