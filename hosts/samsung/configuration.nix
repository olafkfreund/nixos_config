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

    # Note: Tailscale is enabled via services.tailscale (built-in NixOS module)
    # Custom networking.tailscale module was removed during anti-pattern cleanup

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

    # Disable nftables to use iptables (required for security.sshHardening)
    nftables.enable = lib.mkForce false;

    # Set custom nameservers as fallback
    nameservers = [ "1.1.1.1" "8.8.8.8" ];

    # Firewall configuration - explicit SSH access
    # Override common networking module which disables firewall
    firewall = {
      enable = lib.mkForce true;
      allowedTCPPorts = [
        22    # SSH - critical for remote access
        3389  # RDP - for remote desktop (also set by features.gnome-remote-desktop)
        5900  # VNC - for remote desktop (also set by features.gnome-remote-desktop)
      ];
      allowPing = true;  # Enable ICMP for network diagnostics
    };
  };

  # Tailscale VPN using built-in NixOS service
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client"; # Accept routes from other nodes
    openFirewall = true;
  };

  # COSMIC Connect - Device connectivity solution for COSMIC Desktop
  services.cosmic-connect = {
    enable = true;
    openFirewall = true; # Ports 1814-1864 (discovery), 1739-1764 (transfers), 5900 (VNC)
    daemon = {
      enable = true;
      autoStart = true;
    };
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

  # MCP screenshot server for Claude Desktop
  services.rescreenshot-mcp = {
    enable = true;
    user = vars.username;
    logLevel = "info";
    autoConfigureClaudeDesktop = true;
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

    # Enable Claude Code hooks for desktop notifications
    claude-hooks = {
      enable = true;
      enablePermissionNotifications = true;
      enableReadyNotifications = true;
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
      claude-desktop = true; # Enable Claude Desktop GUI with MCP server support

      # Enable MCP (Model Context Protocol) servers for AI integration
      mcp = {
        enable = true;
        # Enable Obsidian MCP server for knowledge base access
        obsidian = {
          enable = true;
          implementation = "rest-api"; # Use REST API mode for full CRUD operations
          vaultPath = "/home/olafkfreund/Documents/Caliti"; # Used for zero-dependency mode
          restApi = {
            apiKeyFile = config.age.secrets."obsidian-api-key".path;
            host = "localhost";
            port = 27123;
            verifySsl = true;
          };
        };
        # Enable Atlassian MCP server for Jira and Confluence integration
        atlassian = {
          enable = true;
          mode = "cloud"; # Atlassian Cloud mode
          jira = {
            enable = true;
            url = "https://synecloud.atlassian.net";
            username = "olaf.krasicki-freund@calitii.com";
            tokenFile = config.age.secrets."api-jira-token".path;
          };
          confluence = {
            enable = true;
            url = "https://synecloud.atlassian.net/wiki";
            username = "olaf.krasicki-freund@calitii.com";
            tokenFile = config.age.secrets."api-confluence-token".path;
          };
        };
        # Enable LinkedIn MCP server for professional networking
        # NOTE: Disabled until secret is created (see docs/LINKEDIN-MCP.md)
        # To enable: ./scripts/manage-secrets.sh create api-linkedin-cookie
        linkedin = {
          enable = false; # TODO: Enable after creating secret
          cookieFile = config.age.secrets."api-linkedin-cookie".path;
        };
        # Enable WhatsApp MCP server for AI-assisted messaging
        whatsapp = {
          enable = true;
          enableVoiceMessages = true; # Enable FFmpeg for voice message conversion
        };
        # Enable additional MCP servers
        servers = {
          browsermcp = true; # Browser automation with privacy
          terraform = true; # Infrastructure as Code support
        };
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

    # COSMIC Desktop with COSMIC Greeter enabled
    desktop.cosmic = {
      enable = true;
      useCosmicGreeter = true; # Using COSMIC Greeter as display manager
      defaultSession = true; # Set COSMIC as default session
      installAllApps = true; # Install full Cosmic app suite
      disableOsd = true; # Workaround for polkit agent crashes in COSMIC beta
    };

    # COSMIC Package Updater Applet - NixOS update notifications
    desktop.cosmic-applet-package-updater = {
      enable = true;
      autoCheck = true;
      checkIntervalMinutes = 60;
      nixosMode = "auto"; # Auto-detect flakes vs channels mode
      enablePasswordlessChecks = false; # Require password for security
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

  # Hardware and service specific configurations
  services = {
    playerctld.enable = true;
    fwupd.enable = true;
    # ollama.package = pkgs.ollama; # Disabled - Ollama not needed on Samsung laptop
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

    # COSMIC desktop extensions
    cosmic-ext-applet-external-monitor-brightness
    cosmic-ext-applet-weather
    # Remote desktop
    rustdesk-flutter
    # Messaging applications
    karere # GTK4 WhatsApp client
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
