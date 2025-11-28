{ pkgs
, config
, lib
, hostUsers
, hostTypes
, ...
}:
let
  vars = import ./variables.nix { };
in
{
  # Use laptop template and add Samsung-specific modules
  imports = hostTypes.laptop.imports ++ [
    # Hardware-specific imports
    ./nixos/hardware-configuration.nix
    ./nixos/screens.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/intel.nix
    ../common/nixos/i18n.nix
    ../common/nixos/hosts.nix
    ../common/nixos/envvar.nix
    ./nixos/cpu.nix
    ./nixos/laptop.nix
    ./nixos/memory.nix
    ./themes/stylix.nix

    # Samsung-specific additional modules
    ../../modules/development/default.nix
    # ../common/hyprland.nix # Disabled to avoid frequent rebuilds
    ../../modules/security/secrets.nix
    ../../modules/secrets/api-keys.nix
    ../../modules/containers/docker.nix
  ];

  # Consolidated networking configuration
  networking = {
    # Set hostname from variables
    inherit (vars) hostName;

    # Choose networking profile: "desktop", "server", or "minimal"
    profile = "desktop";

    # Tailscale VPN Configuration - Samsung laptop
    tailscale = {
      enable = true;
      authKeyFile = config.age.secrets.tailscale-auth-key.path;
      hostname = "samsung-laptop";
      acceptRoutes = true;
      acceptDns = false; # Keep NetworkManager DNS
      ssh = true;
      shields = true;
      useRoutingFeatures = "client"; # Client that accepts routes
      extraUpFlags = [
        "--operator=olafkfreund"
        "--accept-risk=lose-ssh"
      ];
    };

    # Use NetworkManager for simple network management
    networkmanager = {
      enable = true;
      dns = "default"; # Use NetworkManager's built-in DNS
      settings = {
        main = {
          dns = "default";
        };
      };
    };
    useNetworkd = false;

    # Set custom nameservers as fallback
    nameservers = [ "192.168.1.222" "1.1.1.1" "8.8.8.8" ];

    # Firewall configuration for remote desktop moved to features.gnome-remote-desktop
  };

  # Use AI provider defaults with laptop profile (disables Ollama automatically)
  aiDefaults = {
    enable = true;
    profile = "laptop";
  };

  # Enable XDG portal for GNOME screen sharing
  modules.services.xdg-portal = {
    enable = true;
    backend = "gnome";
    enableScreencast = true;
  };

  # Use the new features system instead of multiple lib.mkForce calls
  features = {
    development = {
      enable = true;
      ansible = true;
      cargo = true;
      copilot-cli = true; # GitHub Copilot CLI
      spec-kit = true; # GitHub spec-kit for Spec-Driven Development
      github = true;
      go = true;
      java = true;
      lua = true;
      nix = true;
      shell = true;
      devshell = true; # Re-enabled for Samsung
      python = true;
      nodejs = true;
    };

    gnome-remote-desktop = {
      enable = true;
    };

    virtualization = {
      enable = true;
      docker = true;
      incus = false;
      podman = true;
      spice = true;
      libvirt = true;
    };

    cloud = {
      enable = true;
      aws = true;
      azure = false; # Temporarily disabled due to msgraph-core build failure
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
      ollama = false; # Intel GPU - no local inference
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

    # COSMIC Desktop with COSMIC Greeter enabled
    desktop.cosmic = {
      enable = true;
      useCosmicGreeter = false; # Disabled due to libEGL.so.1 bug (nixpkgs #464392)
      defaultSession = true; # Set COSMIC as default session
      installAllApps = true; # Install full Cosmic app suite
      disableOsd = true; # Workaround for polkit agent crashes in COSMIC beta
    };
  };

  # Use GDM instead of COSMIC greeter until bug is fixed
  services.xserver.displayManager.gdm.enable = true;

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

  # TEMPORARY FIX: Disable tailscale-autoconnect service until auth key is fixed
  # This prevents system activation failures
  systemd.services.tailscale-autoconnect.enable = lib.mkForce false;

  # Nix build optimizations
  nix = {
    settings = {
      max-jobs = lib.mkDefault 12; # i7-1260P has 12 cores/16 threads
      cores = lib.mkDefault 16; # Use all threads
      auto-optimise-store = true;
    };
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';
  };

  # Consolidated services configuration
  services = {
    # Nixai
    nixai = {
      enable = true;
      mcp.enable = true;
    };

    # GNOME Remote Desktop configuration moved to features.gnome-remote-desktop

    # DNS management handled by networking profile

    # Disable secure-dns to use dex5550 DNS server for internal domains
    secure-dns.enable = false;

    # X server and desktop environment
    xserver = {
      enable = true;
      displayManager.xserverArgs = [
        "-nolisten tcp"
        "-dpi 96"
      ];
      videoDrivers = [ vars.gpu ];
    };

    # Desktop environment
    desktopManager.gnome.enable = true;
  };

  # Display manager - Disable GDM to use COSMIC Greeter
  services.displayManager.gdm.enable = lib.mkForce false;

  # Hardware and service specific configurations
  services = {
    playerctld.enable = true;
    fwupd.enable = true;
    ollama.acceleration = vars.acceleration;
    nfs.server = lib.mkIf vars.services.nfs.enable {
      enable = true;
      inherit (vars.services.nfs) exports;
    };
  };

  # CRITICAL: DNS Resolution Fix for Tailscale
  # Ensure proper service ordering to prevent DNS conflicts
  systemd.services = {
    # Disable network wait services to improve boot time
    NetworkManager-wait-online.enable = lib.mkForce false;
  };

  # Use standard NetworkManager for laptop
  networking.useHostResolvConf = false;

  environment.sessionVariables =
    vars.environmentVariables
    // {
      NH_FLAKE = vars.paths.flakeDir;
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

  # Enable secrets management
  modules.security.secrets = {
    enable = true;
    userKeys = [ "/home/${vars.username}/.ssh/id_ed25519" ];
  };

  users.users = lib.genAttrs hostUsers (username: {
    isNormalUser = true;
    description = "User ${username}";
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
    # Only use secret-managed password if the secret exists
    hashedPasswordFile =
      lib.mkIf
        (config.modules.security.secrets.enable
          && builtins.hasAttr "user-password-${username}" config.age.secrets)
        config.age.secrets."user-password-${username}".path;
  });

  # Enable passwordless sudo for wheel group (for NixOS deployments)
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  # System packages - consolidated from individual nixos modules
  environment.systemPackages = with pkgs; [
    # Qt theme control tools for Stylix
    libsForQt5.qt5ct
    kdePackages.qt6ct
    # Power management
    cpupower-gui # GUI for CPU frequency scaling
    powertop # Power consumption analyzer
    lm_sensors # Hardware monitoring
    s-tui # Terminal UI stress test and monitoring tool
    htop # Process viewer with power info
    acpi # Command line battery info

    # Login manager
    tuigreet
  ];

  # Docker configuration
  modules.containers.docker = {
    enable = true;
    users = hostUsers; # Use all users for this host
    rootless = false;
  };

  hardware.nvidia-container-toolkit.enable = false; # Samsung has Intel GPU

  # Windows app integration
  programs.winboat.enable = true;

  # Agenix identity configuration - specify where to find decryption keys
  age.identityPaths = [
    "/home/olafkfreund/.ssh/id_ed25519" # User key
    "/etc/ssh/ssh_host_rsa_key" # Host key (RSA - avoids circular dependency with agenix-managed Ed25519 key)
  ];

  nixpkgs.config = {
    permittedInsecurePackages = [
      "olm-3.2.16"
      "python3.12-youtube-dl-2021.12.17"
      "libsoup-2.74.3" # Temporary: Required by some GNOME packages until migration to libsoup-3
      "electron-35.7.5" # Temporary: Required until upstream packages migrate to newer electron
    ];

    # Allow broken packages (needed for some CUDA dependencies pulled transitively)
    # Samsung is Intel-only, no NVIDIA GPU, but some development tools may pull CUDA
    allowBroken = true;
  };

  system.stateVersion = "25.11";
}
