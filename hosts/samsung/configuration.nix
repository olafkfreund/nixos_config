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
    ./nixos/intel.nix
    ./nixos/i18n.nix
    ./nixos/hosts.nix
    ./nixos/envvar.nix
    ./nixos/greetd.nix
    ./nixos/cpu.nix
    ./nixos/laptop.nix
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
    ../../modules/containers/docker.nix
  ];

  # Set hostname from variables
  networking.hostName = vars.hostName;

  #Nixai
  services.nixai = {
    enable = true;
    mcp.enable = true;
  };

  # Centralized Logging - Send logs to DEX5550 Loki server
  services.promtail-logging = {
    enable = true;
    lokiUrl = "http://dex5550:3100";
    collectJournal = true;
    collectKernel = true;
  };

  # Choose networking profile: "desktop", "server", or "minimal"
  networking.profile = "desktop";

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
      ollama = false;
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

  # IDIOT-PROOF DNS CONFIGURATION: Prevent Tailscale from breaking DNS
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "none"; # Safer default
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

  # Enable secure DNS with DNS over TLS
  services.secure-dns = {
    enable = true;
    dnssec = "true";
    fallbackProviders = [
      "1.1.1.1#cloudflare-dns.com" # Cloudflare DNS
      "8.8.8.8#dns.google" # Google DNS
    ];
  };

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

  # Use variables for nameservers
  networking.nameservers = vars.nameservers;

  # Disable network wait services to improve boot time regardless of network manager
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;

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
