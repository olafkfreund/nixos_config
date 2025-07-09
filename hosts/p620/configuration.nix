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

  # Use static DNS configuration for reliable internal resolution
  services.resolved.enable = lib.mkForce false;
  networking.nameservers = [ "192.168.1.222" "1.1.1.1" "8.8.8.8" ];
  networking.search = [ "home.freundcloud.com" ];

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
      devshell = false; # Temporarily disabled due to patch issue
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
        defaultProvider = "anthropic";
        enableFallback = true;
        
        # Enable specific providers
        openai.enable = true;
        anthropic.enable = true;
        gemini.enable = true;
        ollama.enable = true;
      };
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
    };
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


  scrcpyWifi.enable = true;

  # AI Ollama-specific configuration that goes beyond simple enabling
  ai.ollama = {
    enableRag = true;
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
    extraGroups = ["wheel" "networkmanager"];
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
  programs.streamcontroller.enable = lib.mkForce true;

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
          Domains = "home.freundcloud.com";  # Configure DNS domain for internal resolution
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

  # Package configurations
  nixpkgs.config.permittedInsecurePackages = [
    "olm-3.2.16"
    "python3.12-youtube-dl-2021.12.17"
  ];

  # System version
  system.stateVersion = "25.11";
}
