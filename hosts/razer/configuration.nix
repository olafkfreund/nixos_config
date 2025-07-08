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
    ./nixos/nvidia.nix
    ./nixos/i18n.nix
    ./nixos/hosts.nix
    ./nixos/envvar.nix
    ./nixos/greetd.nix
    ./nixos/cpu.nix
    ./nixos/laptop.nix
    ./nixos/memory.nix
    ./themes/stylix.nix
    ../../modules/default.nix
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

  # Use DHCP-provided DNS servers - simplest approach
  services.resolved.enable = true;
  networking.nameservers = lib.mkForce [];  # Clear custom nameservers
  
  # Use NetworkManager for simple network management
  networking.networkmanager.enable = true;
  networking.useNetworkd = false;

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
      tailscale = true;
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

    # Monitoring configuration - Razer as client
    monitoring = {
      enable = true;
      mode = "client";  # Monitored by dex5550
      serverHost = "dex5550";
      
      features = {
        nodeExporter = true;
        nixosMetrics = true;
        alerting = false;  # Only server handles alerting
      };
    };
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

  # IDIOT-PROOF DNS CONFIGURATION: Prevent Tailscale from breaking DNS
  # Force Tailscale to NEVER manage DNS to avoid conflicts
  vpn.tailscale = {
    enable = true;
    acceptDns = lib.mkForce false; # NEVER let Tailscale touch DNS
    netfilterMode = "off"; # Safer for laptops
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
    
    # Make sure Tailscale starts AFTER DNS is properly configured
    tailscaled = {
      after = [ "network.target" "NetworkManager.service" "systemd-resolved.service" ];
      wants = [ "network.target" ];
      requires = [ "network-online.target" ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };
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

  # Hardware and service specific configurations
  services.playerctld.enable = true;
  services.fwupd.enable = true;
  services.ollama.acceleration = vars.acceleration;
  services.nfs.server = lib.mkIf vars.services.nfs.enable {
    enable = true;
    exports = vars.services.nfs.exports;
  };
  hardware.nvidia-container-toolkit.enable = vars.gpu == "nvidia";

  nixpkgs.config.permittedInsecurePackages = ["olm-3.2.16" "python3.12-youtube-dl-2021.12.17"];
  system.stateVersion = "25.11";
}
