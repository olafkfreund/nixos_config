{ config
, pkgs
, lib
, hostUsers
, hostTypes
, inputs
, ...
}:
let
  vars = import ./variables.nix { };
in
{
  # Use workstation template and add P620-specific modules
  imports = hostTypes.workstation.imports ++ [
    # Hardware-specific imports
    ./nixos/hardware-configuration.nix
    ./nixos/screens.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/amd.nix
    ./nixos/usb-power-fix.nix # Fix USB mouse freezing issues
    ../common/nixos/i18n.nix
    ../common/nixos/hosts.nix
    ../common/nixos/envvar.nix
    ./nixos/cpu.nix
    ./nixos/memory.nix
    ./nixos/load.nix
    ./themes/stylix.nix # Re-enabled after upstream cache fix

    # P620-specific additional modules
    ../../modules/development/default.nix
    ../../modules/security/secrets.nix
    ../../modules/secrets/api-keys.nix
    ../../modules/containers/docker.nix
    ../../modules/scrcpy/default.nix
    ../../modules/system/logging.nix
  ];
  # Consolidated networking configuration
  networking = {
    # Set hostname from variables
    inherit (vars) hostName;

    # Choose networking profile: "desktop", "server", or "minimal"
    profile = "desktop"; # Switch to desktop profile for GNOME NetworkManager integration

    # Note: Tailscale is enabled via services.tailscale (built-in NixOS module)
    # Custom networking.tailscale module was removed during anti-pattern cleanup

    # NetworkManager configuration with explicit DNS management
    networkmanager = {
      dns = lib.mkForce "default"; # Force NetworkManager to handle DNS directly
    };

    # Network performance tuning - removed (module deleted during anti-pattern cleanup)
    # performanceTuning = {
    #   enable = false;
    #   profile = "throughput";
    #
    #   tcpOptimization = {
    #     enable = true;
    #     congestionControl = "bbr";
    #     windowScaling = true;
    #     fastOpen = true;
    #     lowLatency = false; # Prioritize throughput over latency
    #   };
    #
    #   bufferOptimization = {
    #     enable = true;
    #     receiveBuffer = 33554432; # 32MB for high-throughput AI workloads
    #     sendBuffer = 33554432; # 32MB for high-throughput AI workloads
    #     autotuning = true;
    #   };
    #
    #   interHostOptimization = {
    #     enable = true;
    #     hosts = [ "dex5550" "p510" "razer" ];
    #     jumboFrames = false; # Keep disabled for compatibility
    #     routeOptimization = true;
    #   };
    #
    #   dnsOptimization = {
    #     enable = true;
    #     caching = true;
    #     parallelQueries = true;
    #     customServers = [ "192.168.1.222" "1.1.1.1" ];
    #   };
    #
    #   monitoringOptimization = {
    #     enable = true;
    #     compression = true;
    #     batchingInterval = 5; # More frequent for performance workstation
    #     prioritization = true;
    #   };
    # };

    # Firewall disabled - P620 is inside a secure network
    firewall.enable = lib.mkForce false;
  };

  # Tailscale VPN using built-in NixOS service
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both"; # Can route and accept routes
    openFirewall = true;
  };

  # COSMIC Notifications NG - Enhanced notifications with rich content support
  # DISABLED: Module has bug - uses xdg.configFile (Home Manager option) in NixOS module
  # TODO: Fix upstream at github:olafkfreund/cosmic-notifications-ng/nix/module.nix
  # The overlay still provides the package via nixpkgs.overlays
  # services.cosmic-notifications-ng.enable = true;

  # COSMIC Connect - Device connectivity solution for COSMIC Desktop
  # DISABLED: webkit2gtk dependency issue in upstream package
  # TODO: Re-enable when cosmic-connect package is fixed
  # services.cosmic-connect = {
  #   enable = true;
  #   openFirewall = true; # Ports 1814-1864 (discovery), 1739-1764 (transfers), 5900 (VNC)
  #   daemon = {
  #     enable = true;
  #     autoStart = true;
  #   };
  # };

  # Use AI provider defaults with workstation profile
  aiDefaults = {
    enable = true;
    profile = "workstation";
  };


  # Enable Claude Code hooks for desktop notifications
  features.claude-hooks = {
    enable = true;
    enablePermissionNotifications = true;
    enableReadyNotifications = true;
  };

  # Enable AI-powered shell command suggestions
  # Note: Configured via Home Manager (Users/olafkfreund/p620_home.nix)
  # System-level configuration disabled in favor of per-user configuration
  features.zsh-ai-cmd.enable = false;

  # Re-enable Claude Desktop with local package
  # features.ai.claude-desktop = true;

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
      "192.168.1.0/24"
      "10.0.0.0/8"
    ];
  };

  # AI production dashboard and load testing removed - were non-functional services consuming resources

  # Enable NixOS package monitoring tools
  tools.nixpkgs-monitors = {
    enable = true;
    installAll = true;
  };

  # AI alerting removed - was non-functional, handled by DEX5550 monitoring server via Prometheus/Grafana/Alertmanager

  # NVIDIA GeForce NOW cloud gaming (official Flatpak)
  # DISABLED: GeForce NOW Linux beta doesn't support AMD GPUs (p620 has RX 7900)
  # Use browser instead: chromium --app=https://play.geforcenow.com
  modules.services.geforcenow.enable = false;

  # Use the new features system instead of multiple lib.mkForce calls
  features = {
    development = {
      enable = true;
      cargo = true;
      copilot-cli = true; # GitHub Copilot CLI
      spec-kit = true; # GitHub spec-kit for Spec-Driven Development
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

      # Waydroid Android emulation (AMD GPU - standard configuration)
      waydroid = {
        enable = true;
        disableGbm = false; # AMD GPU - standard config
        enableWaydroidHelper = true;
      };
    };

    cloud = {
      enable = true;
      aws = true;
      azure = true; # Temporarily disabled due to msgraph-core build failure
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

    # Syncthing for ~/.claude and ~/.gemini sync across hosts
    syncthing = {
      enable = true;
      syncClaude = true;
      syncGemini = true;
      masterHost = "p620"; # This host is the primary
    };

    ai = {
      enable = true;
      ollama = true;
      gemini-cli = true;
      claude-desktop = true;

      # Enable unified AI provider support
      providers = {
        enable = true;
        defaultProvider = "openai"; # P620-specific override: use OpenAI as default instead of Anthropic
        enableFallback = true;

        # Enable specific providers
        openai.enable = true;
        anthropic.enable = true;
        gemini.enable = true;
        ollama.enable = false; # Disabled to reduce resource usage
      };

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
          mode = "cloud";
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
          enable = false; # Disabled - not working
          enableVoiceMessages = false;
        };
        # Enable additional MCP servers
        servers = {
          browsermcp = true; # Browser automation with privacy
          grafana = true; # Integration with monitoring stack
          terraform = true; # Infrastructure as Code support
        };
      };
    };

    email = {
      enable = true;
      neomutt.enable = true;
      ai.enable = true;
      ai.provider = "openai";
      notifications.enable = true;
      notifications.highPriorityOnly = true;
    };

    programs = {
      lazygit = true;
      thunderbird = true;
      obsidian = true;
      office = true;
      webcam = true;
      print = true;
      yt-x.enable = true; # Terminal YouTube browser
    };

    media = {
      droidcam = false; # Disabled - building custom solution
    };

    # Enable QuickShell for testing (experimental - runs alongside Waybar)
    quickshell = {
      enable = true;
    };

    # Enable COSMIC Desktop with all applications and COSMIC Greeter
    desktop.cosmic = {
      enable = true;
      useCosmicGreeter = true; # Using COSMIC Greeter as display manager
      defaultSession = true; # Set COSMIC as default session
      installAllApps = true;
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

    # Microsoft Intune Company Portal (custom package with version control)
    intune = {
      enable = false; # Disabled - no longer needed
      autoStart = false; # Manual launch - start from application menu as needed
      enableDesktopIntegration = true;
    };
  };

  # Citrix Workspace for client project remote access
  # TODO: Complete manual tarball download - see docs/CITRIX-WORKSPACE-SETUP.md
  services.citrix-workspace = {
    enable = true; # Enabled with version 25.08.10.111
    acceptLicense = true; # Accept Citrix EULA for client project work
  };

  # MCP screenshot server for Claude Desktop
  services.rescreenshot-mcp = {
    enable = true;
    user = vars.username;
    logLevel = "info";
    autoConfigureClaudeDesktop = true;
  };

  # AI service-level configuration (for ai.ollama module options)
  ai.ollama = {
    enableRag = false; # Temporarily disabled due to ChromaDB 1.0.12 startup bug
    ragDirectory = "/home/${vars.username}/documents/rag-files";
    allowBrokenPackages = false;
  };

  # Enable encrypted API keys

  secrets.apiKeys = {
    enable = true; # Re-enabled after recreating secrets with current SSH keys
    enableEnvironmentVariables = true;
    enableUserEnvironment = true;
  };

  # Consolidated system configuration
  system = {
    # Enable logging configuration for noise reduction
    logging = {
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

    # Performance Optimization Configuration - REMOVED
    # The system.resourceManager module was removed during anti-pattern cleanup
    # Module had root services and is no longer needed

    # System version
    stateVersion = "25.11";
  };

  scrcpyWifi.enable = true;

  # Temperature dashboard script
  scripts.tempDashboard.enable = true;

  # Advanced CPU monitoring script for Waybar

  # Consolidated modules configuration
  modules = {
    # Docker configuration
    containers.docker = {
      enable = true;
      users = hostUsers; # Use all users for this host
      rootless = false;
    };

    # Enable secrets management
    security.secrets = {
      enable = true;
      userKeys = [ "/home/${vars.username}/.ssh/id_ed25519" ];
    };
  };

  # Create system users for all host users
  users.users = lib.genAttrs hostUsers (username: {
    isNormalUser = true;
    description = "User ${username}";
    extraGroups = [
      "wheel"
      "networkmanager"
      "render"
    ];
    shell = pkgs.zsh;
    # Only use secret-managed password if the secret exists
    hashedPasswordFile = lib.mkIf
      (
        config.modules.security.secrets.enable
        && builtins.hasAttr "user-password-${username}" config.age.secrets
      )
      config.age.secrets."user-password-${username}".path;
  });

  # Remove duplicate user configuration - use the one above that handles all hostUsers
  # users.users.${vars.username} is now handled by the genAttrs above

  # Consolidated services configuration
  services = {

    # NixOS Update Checker - Safe update detection and management
    nixos-update-checker = {
      enable = true;
      flakeDir = "/home/olafkfreund/.config/nixos";
      checkInterval = "monthly"; # Check for updates monthly
      enableMotd = false; # MOTD disabled - /etc is immutable in NixOS
    };

    # Disable secure-dns to allow NetworkManager to manage DNS directly
    secure-dns.enable = false;

    # GNOME Remote Desktop - Enable RDP and VNC access
    gnome.gnome-remote-desktop = {
      enable = true;
    };

    # Avahi for service discovery (helps with remote desktop discovery)
    avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        userServices = true;
      };
    };

    # X server configuration
    xserver = {
      enable = true;
      displayManager = {
        xserverArgs = [
          "-nolisten tcp"
          "-dpi 96"
        ];
        # Disable LightDM to prevent conflicts with COSMIC Greeter
        lightdm.enable = lib.mkForce false;
      };
      videoDrivers = [ "${vars.gpu}gpu" ]; # Correct way to set the video driver
    };

    # Display manager configuration (modern syntax)
    # GDM is enabled at line 281 until COSMIC Greeter bug is fixed

    # Desktop environment
    desktopManager.gnome.enable = true;

    # File systems and services
    nfs.server = lib.mkIf vars.services.nfs.enable {
      enable = true;
      inherit (vars.services.nfs) exports;
    };

    # Other services
    playerctld.enable = true;
    fwupd.enable = true;

    # ClamAV configuration
    clamav = {
      daemon.enable = true; # Enable clamd (ClamAV daemon)
      updater.enable = true; # Enable freshclam (virus database updater)
    };

    # Ollama specific configurations for AMD GPU
    ollama = {
      enable = true;
      package = pkgs.ollama-rocm; # Use ROCm-enabled package for AMD GPU
      rocmOverrideGfx = lib.mkForce "11.0.0";
      environmentVariables = {
        HCC_AMDGPU_TARGET = lib.mkForce "gfx1100";
        ROC_ENABLE_PRE_VEGA = lib.mkForce "1";
        HSA_OVERRIDE_GFX_VERSION = lib.mkForce "11.0.0";
      };
    };

    # Hardware-specific configurations
    udev = {
      packages = [ pkgs.via ];
      extraRules = builtins.concatStringsSep "\n" [
        ''ACTION=="add", SUBSYSTEM=="video4linux", DRIVERS=="uvcvideo", RUN+="${pkgs.v4l-utils}/bin/v4l2-ctl --set-ctrl=power_line_frequency=1"''
        ''KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", TAG+="uaccess"''
      ];
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
    nix-doc # Interactive Nix documentation tool
    # COSMIC desktop extensions
    cosmic-ext-applet-external-monitor-brightness
    cosmic-ext-applet-weather
    # Remote desktop
    rustdesk-flutter
    # Messaging applications
    karere # GTK4 WhatsApp client
    # Qt theme control tools for Stylix
    libsForQt5.qt5ct
    kdePackages.qt6ct
    # Custom qwen-code package - disabled due to npm registry network errors (HTTP/2 framing layer issue)
    # (callPackage ../../home/development/qwen-code/default.nix { })
    # yt-x terminal YouTube browser
    inputs.yt-x.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # Hardware features
  hardware = {
    keyboard.qmk.enable = true;
    flipperzero.enable = true;
  };

  # File systems
  fileSystems."/mnt/media" = {
    device = "p510.lan:/mnt/media";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
    ];
  };

  # Consolidated systemd configuration
  systemd = {
    # Network configuration now handled by desktop profile (NetworkManager)
    # systemd-networkd conflicts removed

    services = {
      # Network wait services now handled by desktop profile
      fwupd.serviceConfig.LimitNOFILE = 524288;
    };

    # User services
    user.services.scream-ivshmem = {
      enable = true;
      description = "Scream IVSHMEM";
      serviceConfig = {
        ExecStart = "${pkgs.scream}/bin/scream-ivshmem-pulse /dev/shm/scream";
        Restart = "always";
      };
      wantedBy = [ "multi-user.target" ];
      requires = [ "pulseaudio.service" ];
    };
  };

  # Storage performance optimization
  storage.performanceOptimization = {
    enable = true;
    profile = "performance";

    ioSchedulerOptimization = {
      enable = true;
      dynamicScheduling = true;
      ssdOptimization = true;
      hddOptimization = true;
    };

    filesystemOptimization = {
      enable = true;
      readaheadOptimization = true;
      cacheOptimization = true;
      compressionOptimization = false; # Disable for performance
    };

    nvmeOptimization = {
      enable = true;
      queueDepth = 64; # High queue depth for performance
      polling = true;
      multiQueue = true;
    };

    diskCacheOptimization = {
      enable = true;
      writeCache = true;
      readCache = true;
      barrierOptimization = false; # Keep safe
    };

    tmpfsOptimization = {
      enable = true;
      tmpSize = "16G"; # Large temp space for AI workloads and complex builds
      varTmpSize = "2G";
      devShmSize = "50%";
    };
  };

  # AI-powered automated performance tuning removed - was non-functional and consuming resources

  # Agenix identity configuration - use only host keys for system activation
  # This ensures secrets can be decrypted during boot when only root has access
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key" # Primary host key (Ed25519)
    "/etc/ssh/ssh_host_rsa_key" # Fallback host key (RSA)
  ];

  # Windows app integration - Re-enabled after upstream fix (v0.9.0)
  programs.winboat.enable = true;

  # Fix broken GNOME Shell patch in nixpkgs (shell_remove_dark_mode.patch failing on 49.1)
  nixpkgs.overlays = [
    (_final: prev: {
      gnome-shell = prev.gnome-shell.overrideAttrs (oldAttrs: {
        patches = builtins.filter
          (
            patch: !(builtins.match ".*shell_remove_dark_mode.*" (toString patch) != null)
          )
          (oldAttrs.patches or [ ]);
      });
    })
  ];

  # Package configurations
  nixpkgs.config = {
    allowBroken = true;
    permittedInsecurePackages = [
      "olm-3.2.16"
      "python3.12-youtube-dl-2021.12.17"
      "libsoup-2.74.3" # Temporary: Required by some GNOME packages until migration to libsoup-3
      "electron-35.7.5" # Temporary: Required until upstream packages migrate to newer electron
    ];
  };
}
