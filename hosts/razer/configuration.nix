{
  pkgs,
  config,
  lib,
  inputs,
  hostUsers,
  ...
}: let
  vars = import ./variables.nix;
in {
  imports = [
    ./nixos/hardware-configuration.nix # Docker configuration
    ./nixos/screens.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    # ./nixos/secure-boot.nix  # Uncomment when ready to enable Secure Boot
    ./nixos/nvidia.nix
    ./nixos/i18n.nix
    ./nixos/hosts.nix
    ./nixos/envvar.nix
    ./nixos/greetd.nix
    ./nixos/cpu.nix
    ./nixos/laptop.nix
    ./nixos/memory.nix
    ./themes/stylix.nix
    # Modular imports - laptop needs full desktop experience  
    ../../modules/core.nix
    ../../modules/development.nix
    ../../modules/desktop.nix
    ../../modules/cloud.nix
    ../../modules/programs.nix
    ../../modules/virtualization.nix
    ../../modules/monitoring.nix
    ../../modules/email.nix
    ../../modules/performance.nix
    ../../modules/development/default.nix
    ../common/hyprland.nix
    ../../modules/security/secrets.nix
    ../../modules/secrets/api-keys.nix
    ../../modules/containers/docker.nix
  ];

  # Set hostname from variables
  networking.hostName = vars.hostName;

  #Nixai
  services.nixai = {
    enable = true;
    mcp.enable = true;
  };

  # Choose networking profile: "desktop", "server", or "minimal"
  networking.profile = "desktop";
  
  # Tailscale VPN Configuration - Razer mobile laptop
  networking.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscale-auth-key.path;
    hostname = "razer-laptop";
    acceptRoutes = true;
    acceptDns = false;  # Keep NetworkManager DNS
    ssh = true;
    shields = true;
    useRoutingFeatures = "client";  # Client that accepts routes
    extraUpFlags = [
      "--operator=olafkfreund"
      "--accept-risk=lose-ssh"
      "--advertise-tags=tag:laptop,tag:mobile"
    ];
  };

  # Use NetworkManager for DNS management - disable systemd-resolved
  services.resolved.enable = lib.mkForce false;

  # Use NetworkManager for simple network management
  networking.networkmanager = {
    enable = true;
    dns = "default"; # Use NetworkManager's built-in DNS
    # Configure settings using new structured format
    settings = {
      main = {
        dns = "default";
      };
      # Note: global DNS domain settings are not supported in structured format
      # Will use networking.nameservers for DNS configuration instead
    };
  };
  networking.useNetworkd = false;

  # Set custom nameservers as fallback
  networking.nameservers = ["192.168.1.222" "1.1.1.1" "8.8.8.8"];

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

  # Monitoring configuration - Razer as client
  monitoring = {
    enable = true;
    mode = "client"; # Monitored by dex5550
    serverHost = "dex5550";

    features = {
      nodeExporter = true;
      nixosMetrics = true;
      alerting = false; # Only server handles alerting
      gpuMetrics = true; # Enable NVIDIA GPU monitoring
    };
  };

  # Enable hardware monitoring with desktop notifications
  monitoring.hardwareMonitor = {
    enable = true;
    interval = 300; # Check every 5 minutes
    enableDesktopNotifications = true;
    
    criticalThresholds = {
      diskUsage = 90;     # Laptop storage, higher threshold OK
      memoryUsage = 95;   # 32GB RAM, can handle higher usage
      cpuLoad = 200;      # Intel i7-10875H (8 cores/16 threads)
      temperature = 90;   # Laptop CPU, higher temp tolerance
    };
    
    warningThresholds = {
      diskUsage = 80;     # Laptop storage warning
      memoryUsage = 85;   # Memory warning
      cpuLoad = 150;      # Load warning
      temperature = 80;   # Temperature warning for laptop
    };
  };

  # Enable NixOS package monitoring tools
  tools.nixpkgs-monitors = {
    enable = true;
    installAll = true;
  };

  # Enable encrypted API keys
  secrets.apiKeys = {
    enable = true;
    enableEnvironmentVariables = true;
    enableUserEnvironment = true;
  };

  # Nix build optimizations
  nix = {
    settings = {
      max-jobs = lib.mkDefault 16; # i7-10875H has 8 cores/16 threads
      cores = lib.mkDefault 16; # Use all threads
      auto-optimise-store = true;
    };
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';
  };

  # Disable secure-dns to use dex5550 DNS server for internal domains
  services.secure-dns.enable = false;

  services = {
    xserver = {
      enable = true;
      displayManager.xserverArgs = [
        "-nolisten tcp"
        "-dpi 96"
      ];
      videoDrivers = [vars.gpu];
    };

    # Desktop environment
    desktopManager.gnome.enable = true;
  };

  # Docker configuration
  modules.containers.docker = {
    enable = true;
    users = hostUsers; # Use all users for this host
    rootless = false;
  };

  # Use DHCP-provided DNS servers
  # networking.nameservers = vars.nameservers; # Commented out to use DHCP

  # CRITICAL: DNS Resolution Fix for Tailscale
  # Ensure proper service ordering to prevent DNS conflicts
  systemd.services = {
    # Disable network wait services to improve boot time
    NetworkManager-wait-online.enable = lib.mkForce false;
  };

  # Use standard NetworkManager for laptop - useNetworkd already set above
  networking.useHostResolvConf = false;

  environment.sessionVariables =
    vars.environmentVariables
    // {
      NH_FLAKE = vars.paths.flakeDir;
    };

  # Enable secrets management
  modules.security.secrets = {
    enable = true;
    hostKeys = ["/etc/ssh/ssh_host_ed25519_key"];
    userKeys = ["/home/${vars.username}/.ssh/id_ed25519"];
  };

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

  # System packages
  environment.systemPackages = with pkgs; [
    # Custom qwen-code package for system-wide availability
    (callPackage ../../home/development/qwen-code/default.nix {})
  ];

  # Hardware and service specific configurations
  services.playerctld.enable = true;
  services.fwupd.enable = true;
  services.ollama.acceleration = vars.acceleration;
  services.nfs.server = lib.mkIf vars.services.nfs.enable {
    enable = true;
    exports = vars.services.nfs.exports;
  };
  hardware.nvidia-container-toolkit.enable = vars.gpu == "nvidia";

  nixpkgs.config = {
    allowBroken = true;
    permittedInsecurePackages = ["olm-3.2.16" "python3.12-youtube-dl-2021.12.17"];
  };
  system.stateVersion = "25.11";
}
