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
  # Use workstation template for desktop environment with media server modules
  imports =
    hostTypes.workstation.imports
    ++ [
      # Hardware-specific imports
      ./nixos/hardware-configuration.nix
      ./nixos/power.nix
      ./nixos/boot.nix
      ./nixos/nvidia.nix
      ./nixos/network.nix # Network configuration with dual-port Intel card
      ../common/nixos/i18n.nix
      ../common/nixos/envvar.nix
      ./nixos/cpu.nix
      ./nixos/memory.nix
      ../common/nixos/hosts.nix
      ./nixos/plex.nix
      # ./flaresolverr.nix  # Temporarily disabled due to xvfbwrapper Python 3.13 build error

      # P510-specific server modules (media server)
      ../../modules/development/default.nix
      ../../modules/secrets/api-keys.nix
      # Desktop-specific imports (needed for GNOME):
      # ./nixos/greetd.nix      # Display manager - using GDM instead
      ./nixos/screens.nix # Display configuration - needed for desktop
      ./themes/stylix.nix # Theming
      # ../../home/desktop/gnome/default.nix # Home Manager module - can't import here
    ];

  # Basic networking configuration (detailed config in ./nixos/network.nix)
  networking = {
    hostName = vars.hostName;

    # Disable IPv6
    enableIPv6 = false;

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
        "--accept-dns=false" # Explicitly set DNS flag to fix autoconnect
      ];
    };

    # DNS configuration
    nameservers = [ "192.168.1.254" ];
  };

  # Use AI provider defaults with workstation profile (now with desktop environment)
  aiDefaults = {
    enable = true;
    profile = lib.mkForce "workstation"; # Force workstation profile for desktop environment
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
      webcam = false; # Disabled due to v4l2loopback build failures on P510
      print = false;
    };

    media = {
      droidcam = false; # Disabled due to v4l2loopback build failures on P510
    };

    # COSMIC Desktop with COSMIC Greeter enabled
    desktop.cosmic = {
      enable = true;
      useCosmicGreeter = true; # Use COSMIC Greeter like p620
      defaultSession = true; # Set COSMIC as default session
      installAllApps = true;
      disableOsd = true; # Workaround for polkit agent crashes in COSMIC beta
    };
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
  # StreamDeck UI disabled for headless operation
  programs.streamdeck-ui.enable = lib.mkForce false;

  # Enable X server (NVIDIA drivers configured in nvidia.nix)
  services.xserver = {
    enable = true;
    displayManager = {
      xserverArgs = [
        "-nolisten tcp"
        "-dpi 96"
      ];
      # Disable LightDM to prevent conflicts with COSMIC Greeter
      lightdm.enable = lib.mkForce false;
    };
  };

  # Display manager configuration - Disable GDM to use COSMIC Greeter
  services.displayManager.gdm.enable = lib.mkForce false;

  # Desktop manager configuration - minimal GNOME for login only
  services.desktopManager.gnome.enable = true;

  # Essential GNOME services for login screen schemas (minimal set)
  services.gnome = {
    gnome-settings-daemon.enable = true;
    gnome-keyring.enable = true;
    gnome-initial-setup.enable = false;
  };

  # Ensure display manager is enabled in systemd
  systemd.targets.graphical.wants = [ "display-manager.service" ];

  # Fix GNOME Shell GDM typelib issue - multiple approaches
  environment.sessionVariables.GI_TYPELIB_PATH = "${pkgs.gdm}/lib/girepository-1.0";

  # Add GSettings schema path for GDM login screen
  environment.sessionVariables.GSETTINGS_SCHEMA_DIR = "${pkgs.gdm}/share/gsettings-schemas/gdm-${pkgs.gdm.version}/glib-2.0/schemas";

  # Add minimal GNOME packages for login screen functionality
  environment.systemPackages = with pkgs; [
    gdm # Provides the Gdm-1.0 typelib required by GNOME Shell
    gnome-control-center # Provides login-screen schema
    gnome-settings-daemon # Additional GNOME schemas
    # Qt theme control tools for Stylix
    libsForQt5.qt5ct
    kdePackages.qt6ct
    # Custom qwen-code package temporarily disabled due to npm registry network errors
    # (callPackage ../../home/development/qwen-code/default.nix { })
  ];

  # NVIDIA modules now loaded via initrd.kernelModules in nvidia.nix for proper early initialization

  # Environment variables for CUDA support
  environment.variables = {
    CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";
    EXTRA_LDFLAGS = "-L/run/opengl-driver/lib";
    EXTRA_CCFLAGS = "-I/run/opengl-driver/include";
    GI_TYPELIB_PATH = "${pkgs.gdm}/lib/girepository-1.0";
    GSETTINGS_SCHEMA_DIR = "${pkgs.gdm}/share/gsettings-schemas/gdm-${pkgs.gdm.version}/glib-2.0/schemas";
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

    # Disable systemd-networkd completely - using NetworkManager only
    network.enable = lib.mkForce false;
  };

  # User-specific configuration from variables
  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.fullName;
    extraGroups = vars.userGroups;
    shell = pkgs.zsh;
    packages = with pkgs; [
      vim
      wally-cli
      # Custom qwen-code package temporarily disabled due to npm registry network errors
      # (callPackage ../../home/development/qwen-code/default.nix { })
    ];
  };

  # NVIDIA specific configurations
  hardware.keyboard.zsa.enable = true;
  services.ollama.acceleration = vars.acceleration;

  # Agenix identity configuration - specify where to find decryption keys
  age.identityPaths = [
    "/home/olafkfreund/.ssh/id_ed25519" # User key
    "/etc/ssh/ssh_host_ed25519_key" # Host key (Ed25519)
    "/etc/ssh/ssh_host_rsa_key" # Host key (RSA fallback)
  ];

  nixpkgs.config = {
    allowUnfree = true; # Required for NVIDIA drivers
    allowBroken = true;
    permittedInsecurePackages = [ "olm-3.2.16" "dotnet-sdk-6.0.428" "python3.12-youtube-dl-2021.12.17" ];
  };
  system.stateVersion = "25.11";
}
