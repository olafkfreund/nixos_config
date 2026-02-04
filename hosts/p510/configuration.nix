{ pkgs
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
      ./nixos/tailscale-serve.nix # Tailscale Serve for media services
      ./nixos/recyclarr.nix # Recyclarr Trash Guides sync
      ../common/nixos/i18n.nix
      ../common/nixos/envvar.nix
      ./nixos/cpu.nix
      ./nixos/memory.nix
      ../common/nixos/hosts.nix
      ./nixos/plex.nix
      ./flaresolverr.nix # Re-enabled: Testing fix for xvfbwrapper Python 3.13 build error

      # P510-specific server modules (media server)
      ../../modules/development/default.nix
      ../../modules/secrets/api-keys.nix
      # Desktop-specific imports (needed for GNOME):
      # ./nixos/greetd.nix      # Display manager - using GDM instead
      ./nixos/screens.nix # Display configuration - needed for desktop
      ./themes/stylix.nix # Re-enabled after upstream cache fix
      # ../../home/desktop/gnome/default.nix # Home Manager module - can't import here
    ];

  # Basic networking configuration (detailed config in ./nixos/network.nix)
  networking = {
    hostName = vars.hostName;

    # Disable IPv6
    enableIPv6 = false;

    # Disable nftables to use iptables (required for security.sshHardening)
    nftables.enable = lib.mkForce false;

    # Note: Tailscale is enabled via services.tailscale (built-in NixOS module)
    # Custom networking.tailscale module was removed during anti-pattern cleanup

    # DNS configuration - using 192.168.1.1 (router DNS server)
    nameservers = [ "192.168.1.1" "1.1.1.1" ];
  };

  # Tailscale VPN using built-in NixOS service with subnet routing
  # Security is provided by Tailscale - no need for additional firewall
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server"; # Enable subnet routing features
    openFirewall = false; # No firewall needed - Tailscale provides security
    # Allow the Tailscale daemon to expose local subnet and accept routes
    extraUpFlags = [
      "--advertise-routes=192.168.1.0/24" # Advertise local subnet
      "--accept-routes" # Accept routes from other nodes
      "--accept-dns=false" # Disable Tailscale DNS - use local DNS only
    ];
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
      cargo = true;
      github = true;
      go = true;
      java = true;
      lua = true;
      nix = true;
      shell = true;
      devshell = true; # Enable devenv development environment
      python = true;
      nodejs = false; # Temporarily disabled due to version conflict - fix DNS first
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

    # Syncthing for ~/.claude and ~/.gemini sync across hosts
    syncthing = {
      enable = true;
      syncClaude = true;
      syncGemini = true;
      masterHost = "p620";
    };

    homeAssistant = {
      enable = true;
      port = 8123;
      enableCloud = true;
      enableCLI = true;
      tailscaleIntegration = true;
      extraComponents = [
        # Additional integrations
      ];
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

    # COSMIC Desktop disabled - using GNOME for better headless RDP support
    desktop.cosmic = {
      enable = false; # Disabled: compositor not starting properly for headless operation
      useCosmicGreeter = false;
      defaultSession = false;
      installAllApps = false;
      disableOsd = true;
    };

    # Remote Desktop support using GNOME Remote Desktop (native RDP support)
    # Note: cosmic-remote-desktop disabled in favor of native GNOME RDP
    desktop.cosmic-remote-desktop = {
      enable = false; # Disabled: using native GNOME Remote Desktop instead
      protocol = "both";
      rdpPort = 3389;
      vncPort = 5900;
      vncPassword = "p510remote";
      allowedNetworks = [ "192.168.1.0/24" "10.0.0.0/8" ];
      disableScreenLock = false;
      disablePowerManagement = true;
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
    enableFail2Ban = false;
    enableKeyOnlyAccess = true;
    trustedNetworks = [
      "192.168.1.0/24" # Local network
      "10.0.0.0/8" # Private network
      "100.64.0.0/10" # Tailscale CGNAT range
    ];
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

  # DISK SPACE MANAGEMENT: Automatic garbage collection to prevent disk full issues
  storage.garbageCollection = {
    enable = true;
    schedule = "weekly";
    deleteOlderThan = "30d";
    keepGenerations = 5;
    optimizeStore = true;
    minFreeSpace = 20; # Keep at least 20GB free
    aggressiveCleanup = false;
  };

  # Enable Recyclarr synchronization
  services.recyclarr-sync.enable = true;

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

  # Display manager - GDM for headless GNOME desktop (COSMIC not used on this server)
  services.displayManager.gdm.enable = true;

  # Enable auto-login for headless RDP access (override cosmic-remote-desktop module)
  services.displayManager.autoLogin = {
    enable = lib.mkOverride 0 true; # Highest priority override (overrides module's mkForce)
    user = "olafkfreund";
  };

  # Desktop manager configuration - Full GNOME for headless RDP access
  services.desktopManager.gnome.enable = true;

  # GNOME services for full desktop functionality
  services.gnome = {
    gnome-settings-daemon.enable = true;
    gnome-keyring.enable = true;
    gnome-initial-setup.enable = false;
    gnome-remote-desktop.enable = true; # Enable GNOME Remote Desktop for RDP support
  };

  # Ensure display manager is enabled in systemd
  systemd.targets.graphical.wants = [ "display-manager.service" ];

  # Fix GNOME Shell GDM typelib issue - multiple approaches
  environment.sessionVariables.GI_TYPELIB_PATH = "${pkgs.gdm}/lib/girepository-1.0";

  # Add GSettings schema path for GDM login screen
  environment.sessionVariables.GSETTINGS_SCHEMA_DIR = "${pkgs.gdm}/share/gsettings-schemas/gdm-${pkgs.gdm.version}/glib-2.0/schemas";

  # Add minimal GNOME packages for login screen functionality
  # Note: gnome-remote-desktop schemas will be automatically included via services.gnome config
  environment.systemPackages = with pkgs; [
    gdm # Provides the Gdm-1.0 typelib required by GNOME Shell
    gnome-control-center # Provides login-screen schema
    gnome-settings-daemon # Additional GNOME schemas
    gnome-remote-desktop # RDP and VNC remote access
    # Qt theme control tools for Stylix
    libsForQt5.qt5ct
    kdePackages.qt6ct
    # Custom qwen-code package temporarily disabled due to npm registry network errors
    # (callPackage ../../home/development/qwen-code/default.nix { })
    # COSMIC desktop extensions
    cosmic-ext-applet-external-monitor-brightness
    cosmic-ext-applet-weather
    # Remote desktop
    rustdesk-flutter
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

  # Ollama with CUDA acceleration for NVIDIA GPU
  services.ollama.package = pkgs.ollama-cuda;

  # Agenix identity configuration - specify where to find decryption keys
  age.identityPaths = [
    "/home/olafkfreund/.ssh/id_ed25519" # User key
    "/etc/ssh/ssh_host_ed25519_key" # Host key (Ed25519)
    "/etc/ssh/ssh_host_rsa_key" # Host key (RSA fallback)
  ];

  # Disable firewall - P510 is on trusted internal network
  # Security is provided by Tailscale ACLs and router firewall
  # Services: Plex, Sonarr, Radarr, NZBGet, Tautulli, etc. need unrestricted access
  networking.firewall.enable = false;

  nixpkgs.config = {
    allowUnfree = true; # Required for NVIDIA drivers
    allowBroken = true;
    permittedInsecurePackages = [ "olm-3.2.16" "dotnet-sdk-6.0.428" "python3.12-youtube-dl-2021.12.17" ];

    # Override nodejs to use nodejs_24 to avoid version conflicts
    packageOverrides = pkgs: {
      nodejs = pkgs.nodejs_24;
    };
  };
  system.stateVersion = "25.11";
}
