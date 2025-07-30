{
  config, # Add config to the function parameters
  pkgs,
  lib,
  inputs,
  hostUsers,
  ...
}: let
  vars = import ./variables.nix;
in {
  imports = [
    ./nixos/hardware-configuration.nix
    ./nixos/screens.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/amd.nix
    ./nixos/i18n.nix
    ./nixos/hosts.nix
    ./nixos/envvar.nix
    ./nixos/greetd.nix
    ./nixos/cpu.nix
    ./nixos/memory.nix
    ./nixos/load.nix
    ./themes/stylix.nix
    ../../modules/default.nix
    ../../modules/development/default.nix
# ../../modules/microvms/default.nix  # Disabled for now - enable as needed
    ../common/hyprland.nix
    ../../modules/security/secrets.nix
    ../../modules/secrets/api-keys.nix
    ../../modules/containers/docker.nix
    ../../modules/scrcpy/default.nix
    ../../modules/system/logging.nix
  ];
  #Nixai
  services.nixai = {
    enable = true;
    mcp.enable = true;
  };

  # Set hostname from variables
  networking.hostName = vars.hostName;

  # Choose networking profile: "desktop", "server", or "minimal"
  networking.profile = "server";
  
  # Tailscale VPN Configuration
  networking.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscale-auth-key.path;
    hostname = "p620-workstation";
    subnet = "192.168.1.0/24";  # Advertise local subnet
    acceptRoutes = true;
    acceptDns = false;  # Keep local DNS setup
    ssh = true;
    shields = true;
    useRoutingFeatures = "both";  # Can route and accept routes
    extraUpFlags = [
      "--operator=olafkfreund"
      "--accept-risk=lose-ssh"
    ];
  };

  # Use systemd-resolved for proper DNS management with systemd-networkd
  services.resolved = {
    enable = true;
    fallbackDns = [ "192.168.1.222" "1.1.1.1" "8.8.8.8" ];
    domains = [ "home.freundcloud.com" ];
    dnssec = lib.mkForce "false";  # Resolve DNSSEC conflict
  };

  # Configure AI providers directly
  ai.providers = {
    enable = true;
    defaultProvider = "anthropic";
    enableFallback = true;
    
    # Enable specific providers
    openai.enable = true;
    anthropic.enable = true;
    gemini.enable = true;
    ollama.enable = true;
  };
  
  # Enable AI-powered system analysis
  ai.analysis = {
    enable = true;
    aiProvider = "openai";
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
      performanceAnalysis = "hourly";  # Every hour
      maintenanceAnalysis = "daily";   # Once daily
      configDriftCheck = "*:0/6";      # Every 6 hours
      logAnalysis = "*:0/4";           # Every 4 hours
    };
    
    # Enable automation features
    automation = {
      autoApplyOptimizations = false;  # Keep disabled for safety
      autoCorrectDrift = false;        # Keep disabled for safety
      generateReports = true;
    };
  };

  # Enable AI-powered memory optimization
  ai.memoryOptimization = {
    enable = true;
    autoOptimize = true;
    nixStoreOptimization = true;
    logRotation = true;
    
    thresholds = {
      memoryWarning = 75;    # P620 is at 22.8%, set lower threshold
      memoryCritical = 85;   # Prevent memory exhaustion
      diskWarning = 45;      # P620 root disk at 49.6%, set lower threshold
      diskCritical = 55;     # Prevent disk full
    };
  };

  # Enable automated remediation in safe mode for P620
  ai.automatedRemediation = {
    enable = true;
    enableSelfHealing = false;  # Conservative for P620
    safeMode = true;           # Safe mode for P620
    
    notifications = {
      enable = true;
      logFile = "/var/log/ai-analysis/remediation-p620.log";
    };
    
    actions = {
      diskCleanup = true;           # Preventive
      memoryOptimization = true;    # P620 at 22.8% memory
      serviceRestart = false;       # Disabled in safe mode
      configurationReset = false;   # Keep disabled for safety
    };
  };

  # Enable storage analysis for P620 in monitoring mode
  ai.storageAnalysis = {
    enable = true;
    emergencyMode = false;     # P620 at acceptable 49.6% usage
    analysisInterval = "daily"; # Daily monitoring for P620
    reportPath = "/var/lib/ai-analysis/p620-storage-reports";
  };

  # Enable security auditing for P620
  ai.securityAudit = {
    enable = true;
    auditLevel = "comprehensive";  # Full security audit for P620
    autoHardening = false;         # Manual review required
    scheduleInterval = "weekly";   # Weekly security audits
    reportPath = "/mnt/data/security-reports";
  };

  # Enable comprehensive system validation for P620
  ai.systemValidation = {
    enable = true;
    validationLevel = "comprehensive";  # Full validation testing
    enableLoadTesting = false;          # Disable load testing for development system
    testReportPath = "/mnt/data/validation-reports";
  };

  # Enable AI performance optimization
  ai.performanceOptimization = {
    enable = true;
    aiProviderOptimization = true;
    cacheOptimization = true;
    networkOptimization = true;
    systemOptimization = true;
  };

  # Enable SSH security hardening
  security.sshHardening = {
    enable = true;
    allowedUsers = hostUsers;
    allowPasswordAuthentication = false;
    allowRootLogin = false;
    maxAuthTries = 3;
    enableFail2Ban = true;
    enableKeyOnlyAccess = true;
    trustedNetworks = ["192.168.1.0/24" "10.0.0.0/8"];
  };

  # Enable hardware monitoring with desktop notifications
  monitoring.hardwareMonitor = {
    enable = true;
    interval = 300; # Check every 5 minutes
    enableDesktopNotifications = true;
    
    criticalThresholds = {
      diskUsage = 85;     # P620 at 49.6%, lower threshold for early warning
      memoryUsage = 90;   # P620 at 22.8%, higher threshold OK for workstation
      cpuLoad = 200;      # AMD Ryzen 5 PRO 4650G (12 cores)
      temperature = 85;   # AMD CPU, conservative threshold
    };
    
    warningThresholds = {
      diskUsage = 75;     # Early warning for P620
      memoryUsage = 80;   # Memory warning
      cpuLoad = 150;      # Load warning  
      temperature = 75;   # Temperature warning
    };
  };

  # Enable production monitoring dashboard
  ai.productionDashboard = {
    enable = true;
    grafanaUrl = "http://dex5550:3001";
    prometheusUrl = "http://dex5550:9090";
    enableAlerts = true;
    refreshInterval = "30s";
  };

  # Enable load testing for AI services
  ai.loadTesting = {
    enable = true;
    testDuration = "3m";
    maxConcurrentUsers = 8;
    testInterval = "weekly";
    enableContinuousLoad = false;  # Disable continuous load testing for development system
    
    providers = ["anthropic" "ollama"];  # Test available providers
    
    testEndpoints = [
      "http://localhost:9090/-/healthy"    # Prometheus
      "http://localhost:3001/api/health"   # Grafana  
      "http://localhost:11434/api/tags"    # Ollama
    ];
    
    loadTestProfiles = {
      light = {
        users = 3;
        duration = "1m";
        rampUp = "20s";
      };
      moderate = {
        users = 8;
        duration = "3m";
        rampUp = "40s";
      };
      heavy = {
        users = 15;
        duration = "5m";
        rampUp = "1m";
      };
      stress = {
        users = 25;
        duration = "8m";
        rampUp = "2m";
      };
    };
    
    alertThresholds = {
      responseTime = 8000;      # 8 seconds for P620
      errorRate = 10;           # 10% error rate acceptable for development
      throughput = 5;           # 5 requests per second minimum
      cpuUsage = 75;            # 75% CPU usage threshold
      memoryUsage = 80;         # 80% memory usage threshold
    };
    
    reportPath = "/mnt/data/load-test-reports";
  };

  # AI alerting moved to DEX5550 monitoring server
  ai.alerting = {
    enable = false;  # Alerts handled by DEX5550
    enableEmail = true;
    enableSlack = false;        # Disable Slack for now
    enableSms = false;          # Disable SMS for now
    enableDiscord = false;      # Disable Discord for now
    
    # Email configuration
    smtpServer = "smtp.gmail.com";
    smtpPort = 587;
    fromEmail = "ai-alerts@freundcloud.com";
    alertRecipients = ["admin@freundcloud.com"];
    
    # Alert thresholds (tuned for P620)
    alertThresholds = {
      diskUsage = 80;           # 80% disk usage for P620
      memoryUsage = 85;         # 85% memory usage
      cpuUsage = 80;            # 80% CPU usage
      aiResponseTime = 8000;    # 8 seconds for P620
      sshFailedAttempts = 15;   # 15 failed SSH attempts
      serviceDowntime = 300;    # 5 minutes service downtime
      loadTestFailures = 50;    # 50% load test failure rate
    };
    
    # Alert level preferences
    alertLevels = {
      critical = {
        email = true;
        slack = false;
        sms = false;
        discord = false;
      };
      warning = {
        email = true;
        slack = false;
        sms = false;
        discord = false;
      };
      info = {
        email = false;
        slack = false;
        sms = false;
        discord = false;
      };
    };
    
    # Escalation rules
    escalationRules = {
      level1 = {
        timeMinutes = 5;
        recipients = ["admin@freundcloud.com"];
        channels = ["email"];
      };
      level2 = {
        timeMinutes = 15;
        recipients = ["admin@freundcloud.com"];
        channels = ["email"];
      };
      level3 = {
        timeMinutes = 30;
        recipients = ["admin@freundcloud.com"];
        channels = ["email"];
      };
    };
    
    # Maintenance mode (disabled by default)
    maintenanceMode = false;
    
    # Alert suppression rules
    alertSuppressionRules = [
      "health check"
      "connection established"
      "connection closed"
      "router dispatching"
      "body-parser"
    ];
    
    # Notification settings
    notificationRetries = 3;
    notificationTimeout = 30;
  };

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

# microvms = {
    #   enable = true;
    #   dev-vm.enable = true;
    #   test-vm.enable = true;
    #   playground-vm.enable = true;
    # };

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
        defaultProvider = "anthropic";
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
  };

  # Monitoring configuration - P620 as client, dex5550 is now server
  monitoring = {
    enable = true;
    mode = "client";  # Send data to dex5550 monitoring server
    serverHost = "dex5550";
    
    features = {
      nodeExporter = true;
      nixosMetrics = true;
      alerting = false;  # Only server handles alerting
      logging = true;   # Enable Promtail for log collection
      prometheus = false;  # Only server runs Prometheus
      grafana = false;     # Only server runs Grafana
      amdGpuMetrics = true;  # Enable AMD GPU monitoring for P620
      aiMetrics = true;      # Enable AI metrics collection
    };
    
    # Enable AI metrics exporter
    aiMetricsExporter = {
      enable = true;
      port = 9105;
      interval = "30s";
      dataDir = "/var/lib/ai-analysis";
    };
  };

  # Zabbix monitoring removed

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


  scrcpyWifi.enable = true;

  # Temperature dashboard script
  scripts.tempDashboard.enable = true;

  # AI Ollama-specific configuration that goes beyond simple enabling
  ai.ollama = {
    enableRag = false;  # Temporarily disabled due to ChromaDB 1.0.12 startup bug
    ragDirectory = "/home/${vars.username}/documents/rag-files";
    allowBrokenPackages = false;
  };

  # Enable Hyprland system configuration
  modules.desktop.hyprland-uwsm.enable = true;

  # Docker configuration
  modules.containers.docker = {
    enable = true;
    users = hostUsers; # Use all users for this host
    rootless = false;
  };

  # Enable secrets management
  modules.security.secrets = {
    enable = true;
    hostKeys = ["/etc/ssh/ssh_host_ed25519_key"];
    userKeys = ["/home/${vars.username}/.ssh/id_ed25519"];
  };

  # Create system users for all host users
  users.users = lib.genAttrs hostUsers (username: {
    isNormalUser = true;
    description = "User ${username}";
    extraGroups = ["wheel" "networkmanager" "render"];
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

  # Productivity tools
  # Temporarily disabled due to textual package test failures
  # programs.streamcontroller.enable = lib.mkForce true;

  # Service-specific configurations
  services = {
    xserver = {
      enable = true;
      displayManager.xserverArgs = [
        "-nolisten tcp"
        "-dpi 96"
      ];
      videoDrivers = ["${vars.gpu}gpu"]; # Correct way to set the video driver
    };

    # Desktop environment
    desktopManager.gnome.enable = true;

    # File systems and services
    nfs.server = lib.mkIf vars.services.nfs.enable {
      enable = true;
      exports = vars.services.nfs.exports;
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
  };

  # System packages
  environment.systemPackages = with pkgs; [
    rocmPackages.llvm.libcxx
    via
    looking-glass-client
    scream
    vim
    wally-cli
  ];

  # Hardware-specific configurations
  services.udev.packages = [pkgs.via];
  services.udev.extraRules = builtins.concatStringsSep "\n" [
    ''ACTION=="add", SUBSYSTEM=="video4linux", DRIVERS=="uvcvideo", RUN+="${pkgs.v4l-utils}/bin/v4l2-ctl --set-ctrl=power_line_frequency=1"''
    ''KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", TAG+="uaccess"''
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
    options = ["x-systemd.automount" "noauto"];
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
          DHCP = "ipv4";
          IPv6AcceptRA = true;
          Domains = "home.freundcloud.com";
          DNS = [ "192.168.1.222" "1.1.1.1" ];
        };
        # Higher priority for wired connection
        dhcpV4Config = {
          RouteMetric = 10;
        };
      };
      "25-wireless" = {
        matchConfig.Name = "wl*";
        networkConfig = {
          MulticastDNS = false;
          DHCP = "ipv4";
          IPv6AcceptRA = true;
        };
        # Lower priority for wireless
        dhcpV4Config = {
          RouteMetric = 20;
        };
      };
    };
  };

  # User services
  systemd.user.services.scream-ivshmem = {
    enable = true;
    description = "Scream IVSHMEM";
    serviceConfig = {
      ExecStart = "${pkgs.scream}/bin/scream-ivshmem-pulse /dev/shm/scream";
      Restart = "always";
    };
    wantedBy = ["multi-user.target"];
    requires = ["pulseaudio.service"];
  };

  # Nix configuration
  nix.settings.allowed-users = ["nix-serve"];

  # Performance Optimization Configuration (Phase 10.4)
  # High-performance AMD workstation profile
  system.resourceManager = {
    enable = true;
    profile = "performance";
    
    cpuManagement = {
      enable = true;
      dynamicGovernor = true;
      affinityOptimization = true;
      coreReservation = false;  # Use all cores for maximum performance
    };
    
    memoryManagement = {
      enable = true;
      dynamicSwap = true;
      hugePagesOptimization = true;
      memoryCompression = false;  # Disable for performance
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
    profile = "throughput";  # Optimize for AI workload throughput
    
    tcpOptimization = {
      enable = true;
      congestionControl = "bbr";
      windowScaling = true;
      fastOpen = true;
      lowLatency = false;  # Prioritize throughput over latency
    };
    
    bufferOptimization = {
      enable = true;
      receiveBuffer = 33554432;  # 32MB for high-throughput AI workloads
      sendBuffer = 33554432;     # 32MB for high-throughput AI workloads
      autotuning = true;
    };
    
    interHostOptimization = {
      enable = true;
      hosts = ["dex5550" "p510" "razer"];
      jumboFrames = false;  # Keep disabled for compatibility
      routeOptimization = true;
    };
    
    dnsOptimization = {
      enable = true;
      caching = true;
      parallelQueries = true;
      customServers = ["192.168.1.222" "1.1.1.1"];
    };
    
    monitoringOptimization = {
      enable = true;
      compression = true;
      batchingInterval = 5;  # More frequent for performance workstation
      prioritization = true;
    };
  };
  
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
      compressionOptimization = false;  # Disable for performance
    };
    
    nvmeOptimization = {
      enable = true;
      queueDepth = 64;  # High queue depth for performance
      polling = true;
      multiQueue = true;
    };
    
    diskCacheOptimization = {
      enable = true;
      writeCache = true;
      readCache = true;
      barrierOptimization = false;  # Keep safe
    };
    
    tmpfsOptimization = {
      enable = true;
      tmpSize = "16G";     # Large temp space for AI workloads and complex builds
      varTmpSize = "2G";
      devShmSize = "50%";
    };
  };
  
  # Performance analytics
  monitoring.performanceAnalytics = {
    enable = true;
    dataRetention = "30d";
    analysisInterval = "1m";  # Frequent analysis for performance workstation
    
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
  
  # AI-powered automated performance tuning
  ai.autoPerformanceTuner = {
    enable = true;
    aiProvider = "openai";
    enableFallback = true;
    tuningInterval = "30min";  # Frequent tuning for performance workstation
    safeMode = false;  # Allow aggressive optimizations on performance workstation
    
    features = {
      adaptiveTuning = true;
      predictiveOptimization = true;
      workloadDetection = true;
      resourceBalancing = true;
      anomalyCorrection = true;
    };
    
    thresholds = {
      cpuUtilization = 75;     # Lower threshold for performance work.station
      memoryUtilization = 80;
      ioWait = 25;            # Lower threshold for fast storage
      responseTime = 3000;    # Stricter response time requirement
    };
    
    notifications = {
      enable = true;
      logFile = "/var/log/ai-analysis/auto-tuner-p620.log";
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
