{ config
, pkgs
, lib
, hostUsers
, hostTypes
, ...
}:
let
  vars = import ./variables.nix { };
in
{
  # Use workstation template and add P510-specific modules
  imports = hostTypes.workstation.imports ++ [
    # Hardware-specific imports
    ./nixos/hardware-configuration.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/nvidia.nix
    ../common/nixos/i18n.nix
    ../common/nixos/envvar.nix
    ./nixos/cpu.nix
    ./nixos/memory.nix
    ./nixos/greetd.nix
    ../common/nixos/hosts.nix
    ./nixos/screens.nix
    ./nixos/plex.nix
    ./flaresolverr.nix
    ./themes/stylix.nix

    # P510-specific additional modules (media server)
    ../../modules/development/default.nix
    ../common/hyprland.nix
    ../../modules/secrets/api-keys.nix
  ];

  # Networking configuration
  networking = {
    hostName = vars.hostName;
    profile = "server";
    useNetworkd = lib.mkForce true;
    useHostResolvConf = false;

    # Tailscale VPN Configuration - P510 media server
    tailscale = {
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
  };

  # Use systemd-resolved for proper DNS management with systemd-networkd
  services.resolved = {
    enable = true;
    fallbackDns = [ "192.168.1.222" "1.1.1.1" "8.8.8.8" ];
    domains = [ "home.freundcloud.com" ];
    dnssec = lib.mkForce "false"; # Resolve DNSSEC conflict
  };

  # Use AI provider defaults with workstation profile
  aiDefaults = {
    enable = true;
    profile = "workstation";
  };

  # AI analysis services removed - were non-functional and consuming resources
  # ai.analysis = {
  #   enable = false;  # Removed completely - provided no meaningful analysis
  #   aiProvider = "openai";
  # };

  # AI memory optimization removed - was non-functional and consuming resources

  # AI automated remediation removed - was non-functional and consuming resources

  # Non-functional AI modules removed - were consuming resources without providing value
  # ai.storageAnalysis = {
  #   enable = false;  # Removed - no meaningful analysis output
  # };
  # ai.backupStrategy = {
  #   enable = false;  # Removed - no actual backups being created
  # };
  # ai.storageExpansion = {
  #   enable = false;  # Removed - no expansion planning functionality
  # };
  # ai.storageMigration = {
  #   enable = false;  # Removed - no migration functionality
  # };
  # ai.securityAudit = {
  #   enable = false;  # Removed - no actual audits performed
  # };

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
      claude-desktop = false; # Disable GUI app on media server
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

  # Centralized Logging - Send logs to DEX5550 Loki server
  services.promtail-logging = {
    enable = true;
    lokiUrl = "http://dex5550:3100";
    collectJournal = true;
    collectKernel = true;
    # Enable nginx logs collection for media server
    collectNginx = false; # Set to true if using nginx
  };

  # Enable NixOS package monitoring tools
  tools.nixpkgs-monitors = {
    enable = true;
    installAll = true;
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
    trustedNetworks = [ "192.168.1.0/24" "10.0.0.0/8" ];
  };

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
    videoDrivers = [ "${vars.gpu}" ];
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
  systemd = {
    services = {
      NetworkManager-wait-online.enable = lib.mkForce false;
      systemd-networkd-wait-online.enable = lib.mkForce false;
    };

    # Configure systemd-networkd for your network interfaces
    # Ensure the interface name matches the output of `ip link` (e.g., eno1)
    network = {
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
  };

  # System packages
  environment.systemPackages = with pkgs; [
    # Qt theme control tools for Stylix
    libsForQt5.qt5ct
    kdePackages.qt6ct
    # Custom qwen-code package for system-wide availability
    (callPackage ../../home/development/qwen-code/default.nix { })
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
      (callPackage ../../home/development/qwen-code/default.nix { })
    ];
  };

  # NVIDIA specific configurations
  hardware.keyboard.zsa.enable = true;
  services.ollama.acceleration = vars.acceleration;
  hardware.nvidia-container-toolkit.enable = true;

  # Agenix identity configuration - specify where to find decryption keys
  age.identityPaths = [
    "/home/olafkfreund/.ssh/id_ed25519" # User key
    "/etc/ssh/ssh_host_ed25519_key" # Host key (Ed25519)
    "/etc/ssh/ssh_host_rsa_key" # Host key (RSA fallback)
  ];

  nixpkgs.config = {
    allowBroken = true;
    permittedInsecurePackages = [ "olm-3.2.16" "dotnet-sdk-6.0.428" "python3.12-youtube-dl-2021.12.17" ];
  };
  system.stateVersion = "25.11";
}
