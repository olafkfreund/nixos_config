{
  config,
  pkgs,
  inputs,
  lib,
  hostUsers,
  ...
}: let
  vars = import ./variables.nix;
in {
  imports = [
    # inputs.microvm.nixosModules.host

    ./nixos/hardware-configuration.nix # Docker configuration
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/nvidia.nix
    ./nixos/i18n.nix
    ./nixos/envvar.nix
    ./nixos/cpu.nix
    ./nixos/memory.nix
    ./nixos/greetd.nix
    ./nixos/hosts.nix
    ./nixos/screens.nix
    ./nixos/plex.nix
    ./flaresolverr.nix
    ./themes/stylix.nix
    ../../modules/server.nix
    ../../modules/default.nix
    ../../modules/development/default.nix
    ../common/hyprland.nix
    ../../modules/secrets/api-keys.nix
  ];

  # Set hostname from variables
  networking.hostName = vars.hostName;

  # Choose networking profile: "desktop", "server", or "minimal"
  networking.profile = "server";

  # Tailscale VPN Configuration - P510 media server
  networking.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscale-auth-key.path;
    hostname = "p510-media";
    acceptRoutes = true;
    acceptDns = false; # Keep local DNS setup
    ssh = true;
    shields = true;
    useRoutingFeatures = "client"; # Accept routes from other nodes
    extraUpFlags = [
      "--operator=olafkfreund"
      "--accept-risk=lose-ssh"
      "--advertise-tags=tag:server,tag:media"
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
      performanceAnalysis = "hourly"; # Every hour
      maintenanceAnalysis = "daily"; # Once daily
      configDriftCheck = "*:0/6"; # Every 6 hours
      logAnalysis = "*:0/4"; # Every 4 hours
    };
  };

  # Enable AI-powered memory optimization - CRITICAL for P510 with 79.6% disk usage
  ai.memoryOptimization = {
    enable = true;
    autoOptimize = true;
    nixStoreOptimization = true;
    logRotation = true;

    thresholds = {
      memoryWarning = 80; # P510 is at 12.5%, normal threshold
      memoryCritical = 90; # Standard critical threshold
      diskWarning = 75; # P510 is at 79.6%, urgent threshold
      diskCritical = 85; # Prevent disk full - already close!
    };
  };

  # Enable automated remediation - CRITICAL for P510 disk space management
  ai.automatedRemediation = {
    enable = true;
    enableSelfHealing = true; # Enable for P510 due to critical disk usage
    safeMode = false; # Disable safe mode for P510 - aggressive cleanup needed

    notifications = {
      enable = true;
      logFile = "/var/log/ai-analysis/remediation-p510.log";
    };

    actions = {
      diskCleanup = true; # Critical - P510 at 79.6%
      memoryOptimization = true; # Preventive
      serviceRestart = true; # Enable for P510
      configurationReset = false; # Keep disabled for safety
    };
  };

  # Enable emergency storage analysis for P510 critical disk situation
  ai.storageAnalysis = {
    enable = true;
    emergencyMode = true; # CRITICAL: P510 at 79.6% disk usage
    analysisInterval = "*:0/30"; # Every 30 minutes for critical monitoring
    reportPath = "/var/lib/ai-analysis/p510-storage-reports";
  };

  # Enable critical backup strategy for P510 before aggressive cleanup
  ai.backupStrategy = {
    enable = true;
    criticalMode = true; # Enable frequent backups for P510
    backupPath = "/mnt/img_pool/backups"; # Use img_pool (only 5.1% used)
    retentionDays = 7; # Keep backups for 7 days due to space constraints

    remoteBackup = {
      enable = true;
      targetHost = "p620"; # Backup to P620 with more space
      targetPath = "/mnt/data/p510-backups";
    };
  };

  # Enable storage expansion analysis for P510 optimization
  ai.storageExpansion = {
    enable = true;
    analysisMode = "expansion"; # Full expansion planning for P510
    recommendationsPath = "/mnt/img_pool/storage-recommendations";
  };

  # Enable emergency storage migration for P510 critical situation
  ai.storageMigration = {
    enable = true;
    targetVolume = "/mnt/img_pool"; # 938GB available, only 5.1% used
    migrationMode = "preparation"; # Start with preparation mode for safety
  };

  # Enable comprehensive security auditing for P510
  ai.securityAudit = {
    enable = true;
    auditLevel = "comprehensive"; # Full security audit for P510
    autoHardening = false; # Manual review required for P510
    scheduleInterval = "daily"; # Daily security audits
    reportPath = "/mnt/img_pool/security-reports";
  };

  # Use the new features system instead of multiple lib.mkForce calls
  features = {
    development = {
      enable = true;
      ansible = false;
      cargo = true;
      github = true;
      go = true;
      java = true;
      lua = true;
      nix = true;
      shell = true;
      devshell = true; # Enable devenv development environment
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
      aws = false;
      azure = false;
      google = false;
      k8s = false;
      terraform = false;
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
    };

    programs = {
      lazygit = true;
      thunderbird = false;
      obsidian = false;
      office = false;
      webcam = true;
      print = false;
    };

    media = {
      droidcam = true;
    };
  };

  # Monitoring configuration - P510 as client
  monitoring = {
    enable = true;
    mode = "client"; # Monitored by dex5550
    serverHost = "dex5550";

    features = {
      nodeExporter = true;
      nixosMetrics = true;
      alerting = false; # Only server handles alerting
      gpuMetrics = true; # Enable NVIDIA GPU monitoring
      networkDiscovery = true; # Enable network discovery from media server
    };

    # Enable NZBGet monitoring
    nzbgetExporter = {
      enable = true;
      nzbgetUrl = "http://localhost:6789";
      username = "nzbget";
      password = "Xs4monly4e!!";
      port = 9103;
      interval = "30s";
    };

    # Enable Plex monitoring
    plexExporter = {
      enable = true;
      tautulliUrl = "http://localhost:8181";
      apiKey = "099a2877fb7c410fb3031e24b3e781bf"; # You'll need to get this from Tautulli settings
      port = 9104;
      interval = "60s";
      historyDays = 30;
    };
  };

  # Zabbix monitoring removed

  # Enable encrypted API keys
  secrets.apiKeys = {
    enable = true;
    enableEnvironmentVariables = true;
    enableUserEnvironment = true;
  };

  # BOOT PERFORMANCE: Prevent fstrim from blocking boot (saves 8+ minutes)
  services.fstrim-optimization = {
    enable = true;
    preventBootBlocking = true;
  };

  # Specific service configurations
  programs.streamdeck-ui = {
    enable = true;
    autoStart = true;
  };

  services.xserver = {
    enable = true;
    displayManager.xserverArgs = [
      "-nolisten tcp"
      "-dpi 96"
    ];
    videoDrivers = ["${vars.gpu}"];
  };

  # Hardware-specific configurations
  security.wrappers.sunshine = {
    owner = "root";
    group = "root";
    capabilities = "cap_sys_admin+p";
    source = "${pkgs.sunshine}/bin/sunshine";
  };

  # Docker configuration
  modules.containers.docker = {
    enable = true;
    users = hostUsers; # Use all users for this host
    rootless = false;
  };

  # Network-specific overrides that go beyond the network profile
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

  # In case the networking profile doesn't apply all needed settings
  networking.useNetworkd = lib.mkForce true;
  networking.useHostResolvConf = false;

  # Configure systemd-networkd for your network interfaces
  # Ensure the interface name matches the output of `ip link` (e.g., eno1)
  systemd.network = {
    enable = true;
    networks = {
      eno1 = {
        name = "eno1";
        DHCP = "ipv4";
        networkConfig = {
          MulticastDNS = false;
          IPv6AcceptRA = true;
          Domains = "home.freundcloud.com"; # Configure DNS domain for internal resolution
        };
        dhcpV4Config = {
          RouteMetric = 10;
        };
      };
    };
  };

  # System packages
  environment.systemPackages = with pkgs; [
    # Custom qwen-code package for system-wide availability
    (callPackage ../../home/development/qwen-code/default.nix {})
  ];

  # User-specific configuration from variables
  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.fullName;
    extraGroups = vars.userGroups;
    shell = pkgs.zsh;
    packages = with pkgs; [
      vim
      wally-cli
      # Custom qwen-code package
      (callPackage ../../home/development/qwen-code/default.nix {})
    ];
  };

  # NVIDIA specific configurations
  hardware.keyboard.zsa.enable = true;
  services.ollama.acceleration = vars.acceleration;
  hardware.nvidia-container-toolkit.enable = true;

  nixpkgs.config = {
    allowBroken = true;
    permittedInsecurePackages = ["olm-3.2.16" "dotnet-sdk-6.0.428" "python3.12-youtube-dl-2021.12.17"];
  };
  system.stateVersion = "25.11";
}
