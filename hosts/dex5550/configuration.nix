{
  pkgs,
  lib,
  hostUsers,
  ...
}: let
  vars = import ./variables.nix;
in {
  imports = [
    ./nixos/hardware-configuration.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/i18n.nix
    ../../modules/default.nix
    ../../modules/development/default.nix
    ../../modules/secrets/api-keys.nix
  ];

  # Set hostname from variables
  networking.hostName = vars.hostName;

  # Choose networking profile: "server" for server configuration
  networking.profile = "server";

  # Configure AI providers directly - lightweight config for low-power system
  ai.providers = {
    enable = true;
    defaultProvider = "anthropic";
    enableFallback = true;
    
    # Enable only cloud providers (no local Ollama to save resources)
    openai.enable = true;
    anthropic.enable = true;
    gemini.enable = true;
    ollama.enable = false;  # Disabled on low-power system
  };

  # Use nameservers from variables
  networking.nameservers = vars.nameservers;

  # Use the new features system instead of multiple lib.mkForce calls
  features = {
    development = {
      enable = true;
      ansible = true;   # Useful for server automation
      cargo = true;
      github = true;
      go = true;
      java = false;
      lua = true;
      nix = true;
      shell = true;
      devshell = false;
      python = true;
      nodejs = true;
    };

    virtualization = {
      enable = true;
      docker = true;
      incus = true;     # Enable for server containers
      podman = true;
      spice = false;    # No GUI needed
      libvirt = true;   # Keep for server VMs
      sunshine = false; # No remote desktop needed
    };

    cloud = {
      enable = false;
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
      tailscale = true;
    };

    ai = {
      enable = true;   # Enable AI tools but no local inference
      ollama = false;  # Keep disabled - too resource intensive for SFF
    };

    programs = {
      lazygit = true;      # CLI tool, useful for server
      thunderbird = false;
      obsidian = false;
      office = false;
      webcam = false;      # No camera needed on server
      print = false;
    };

    media = {
      droidcam = false;    # No media capture on server
    };

    # Monitoring configuration - DEX5550 as client
    monitoring = {
      enable = true;
      mode = "client";  # Monitored by P620
      serverHost = "p620";
      
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

  # IDIOT-PROOF DNS CONFIGURATION: Prevent Tailscale from breaking DNS
  vpn.tailscale = {
    enable = true;
    acceptDns = lib.mkForce false; # NEVER let Tailscale touch DNS
    netfilterMode = "off"; # Safer default
  };

  # BOOT PERFORMANCE: Prevent fstrim from blocking boot (saves 3+ minutes)
  services.fstrim-optimization = {
    enable = true;
    preventBootBlocking = true;
  };

  # Server configuration - no GUI services needed
  services.xserver.enable = false;

  # Server-specific configurations - no GUI hardware wrappers needed

  # Docker configuration
  modules.containers.docker = {
    enable = true;
    users = hostUsers; # Use all users for this host
    rootless = false;
  };

  # User-specific configuration from variables
  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.fullName;
    extraGroups = [
      "networkmanager"
      "libvirtd"
      "wheel"
      "docker"
      "podman"
      "lxd"
      "incus-admin"
    ];
    shell = pkgs.zsh;
    packages = with pkgs; [
      vim
      htop
      tmux
      curl
      wget
      git
    ];
  };

  # Server hardware configurations
  hardware.keyboard.zsa.enable = false; # No physical keyboard management needed
  services.ollama.acceleration =
    if vars.acceleration != ""
    then vars.acceleration
    else "cpu";
  hardware.nvidia-container-toolkit.enable = false;

  nixpkgs.config.permittedInsecurePackages = ["olm-3.2.16" "python3.12-youtube-dl-2021.12.17"];

  system.stateVersion = "25.11";
}
