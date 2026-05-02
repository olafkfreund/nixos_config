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
  # Use laptop template and add Razer-specific modules
  imports = hostTypes.laptop.imports ++ [
    # Hardware-specific imports
    ./nixos/hardware-configuration.nix
    ./nixos/screens.nix
    ./nixos/power.nix
    ./nixos/boot.nix
    ./nixos/secure-boot.nix # Secure Boot enabled with lanzaboote (issue #376)
    ./nixos/shim.nix # Microsoft-signed shim + MOK enrollment for Razer's locked PK (issue #376)
    ./nixos/nvidia.nix
    ../common/nixos/i18n.nix
    ../common/nixos/hosts.nix
    ../common/nixos/envvar.nix
    ../common/nixos/host-class.nix
    ./nixos/cpu.nix
    ./nixos/laptop.nix
    ./nixos/memory.nix
    ./themes/stylix.nix # Re-enabled after upstream cache fix

    # Razer-specific additional modules
    ../../modules/development/default.nix
    ../../modules/security/secrets.nix
    ../../modules/secrets/api-keys.nix
    ../../modules/containers/docker.nix
  ];

  host.class = "laptop";

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
      # Configure settings using new structured format
      settings = {
        main = {
          dns = "default";
        };
        # Note: global DNS domain settings are not supported in structured format
        # Will use networking.nameservers for DNS configuration instead
      };
    };
    useNetworkd = false;

    # Set custom nameservers as fallback
    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];

    # Firewall disabled to allow all network access including SSH
    firewall.enable = lib.mkForce false;
  };

  # Tailscale VPN using built-in NixOS service
  services.tailscale = {
    enable = true;
    # "none": do not accept subnet routes. razer is directly on 192.168.1.0/24,
    # and p510 advertises that same /24 as a subnet route. With accept-routes on,
    # razer's routing table 52 sent LAN-destined replies back through tailscale0,
    # causing asymmetric routing that broke TCP/ICMP to LAN peers (e.g. p620).
    # Note: flipping this flag in Nix does not rewrite tailscale's persisted
    # prefs; run `sudo tailscale set --accept-routes=false` once after switch.
    useRoutingFeatures = "none";
    openFirewall = true;
  };

  # COSMIC Notifications NG - Disabled: removed from active config
  # services.cosmic-ext-notifications = {
  #   enable = true;
  #   settings.max_image_size = 32;
  # };

  # COSMIC BG - Disabled pending upstream fix for startup race condition
  # See: https://github.com/olafkfreund/cosmic-ext-bg/issues/32
  # services.cosmic-ext-bg.enable = true;

  # COSMIC Radio Applet - Internet radio player for COSMIC Desktop panel
  # Add to panel via: COSMIC Settings > Panel > Applets
  programs.cosmic-ext-applet-radio.enable = true;

  # COSMIC Connect - Device connectivity solution for COSMIC Desktop
  # TEMPORARILY DISABLED: Rust compilation errors in cosmic-ext-connect-protocol (issue #79)
  # services.cosmic-ext-connect = {
  #   enable = true;
  #   openFirewall = true; # Ports 1814-1864 (discovery), 1739-1764 (transfers), 5900 (VNC)
  #   daemon = {
  #     enable = true;
  #     autoStart = true;
  #   };
  # };

  # Use AI provider defaults with laptop profile (disables Ollama for battery life)
  aiDefaults = {
    enable = true;
    profile = "laptop";
  };

  # AI analysis services removed - were non-functional and consuming resources
  # ai.analysis = {
  #   enable = false;  # Removed completely - provided no meaningful analysis
  #   aiProvider = "openai";
  # };

  # NVIDIA GeForce NOW cloud gaming (official Flatpak)
  modules.services.geforcenow = {
    enable = true;
    autoInstall = true;
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

    # Enable Claude Code hooks for desktop notifications
    claude-hooks = {
      enable = true;
      enablePermissionNotifications = true;
      enableReadyNotifications = true;
    };

    # GNOME Remote Desktop disabled - using headless service instead
    gnome-remote-desktop = {
      enable = false;
    };

    virtualization = {
      enable = true;
      docker = true;
      incus = false;
      podman = true;
      spice = true;
      libvirt = true;
      # Waydroid Android emulation (NVIDIA GPU - requires GBM disable)
      waydroid = {
        enable = true;
        disableGbm = true; # Required for NVIDIA hybrid graphics
        enableWaydroidHelper = true;
      };
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

    # Syncthing for ~/.claude and ~/.gemini sync across hosts
    syncthing = {
      enable = true;
      syncClaude = true;
      syncGemini = true;
      masterHost = "p620";
    };

    ai = {
      enable = true;
      gemini-cli = true;
      claude-desktop = true; # Enable Claude Desktop GUI with MCP server support

      # Enable MCP (Model Context Protocol) servers for AI integration
      mcp = {
        enable = true;
        obsidian = {
          enable = true;
          implementation = "rest-api";
          restApi.apiKeyFile = config.age.secrets."obsidian-api-key".path;
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
          enable = false; # Disabled - not working
          enableVoiceMessages = false;
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
      thunderbird = false;
      obsidian = true;
      office = true;
      webcam = true; # OBS Virtual Camera support
      print = true;
    };

    media = {
      droidcam = false; # Disabled - building custom solution
    };

    # COSMIC Desktop with COSMIC Greeter enabled
    desktop.cosmic = {
      enable = true;
      useCosmicGreeter = true; # Using COSMIC Greeter as display manager
      defaultSession = true;
      installAllApps = true;
    };

    # Microsoft Intune Company Portal (custom package with version control)
    intune = {
      enable = false; # Disabled - no longer needed
      autoStart = false; # Manual launch - start from application menu as needed
      enableDesktopIntegration = true;
    };
  };

  # Citrix Workspace for client project remote access
  # Disabled — no longer needed. Module + overlay + package retained so this
  # can be flipped back to true without re-installing anything.
  services.citrix-workspace = {
    enable = false;
    acceptLicense = true;
  };

  # MCP screenshot server for Claude Desktop
  services.rescreenshot-mcp = {
    enable = true;
    user = vars.username;
    logLevel = "info";
    autoConfigureClaudeDesktop = true;
  };

  # Auto-sync Chrome PWA icons into the XDG hicolor tree (issue #397).
  # Chrome stores PWA PNG files inside its profile dir, which no launcher indexes;
  # this module symlinks them where COSMIC/GNOME can find them.
  modules.programs.chrome-pwa-icons = {
    enable = true;
    user = vars.username;
  };

  # Claude Code managed-settings.json — read-only baseline (issue #398).
  # PARR hook lives here (highest precedence, cannot be disabled by the
  # user via `claude` CLI). User-scope ~/.claude/settings.json remains
  # writable for plugin installs and runtime mutations.
  modules.programs.claude-code-managed = {
    enable = true;
    parrProtocol.enable = true;
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

  # Consolidated services configuration
  services = {

    # GNOME Remote Desktop configuration moved to features.gnome-remote-desktop

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

    # Desktop environments — COSMIC is the primary session; GNOME is also
    # available as a choice in the login greeter.
    desktopManager.gnome.enable = true;
  };

  # Hardware and service specific configurations
  services = {
    # Explicitly disable gnome-remote-desktop system service (using headless instead)
    gnome.gnome-remote-desktop.enable = lib.mkForce false;

    playerctld.enable = true;
    fwupd.enable = true;
    nfs.server = lib.mkIf vars.services.nfs.enable {
      enable = true;
      inherit (vars.services.nfs) exports;
    };
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
  # Network profile handles service ordering automatically

  # Use standard NetworkManager for laptop - useNetworkd already set above
  networking.useHostResolvConf = false;

  environment.sessionVariables = vars.environmentVariables // {
    NH_FLAKE = vars.paths.flakeDir;
  };

  # Enable secrets management
  modules.security.secrets = {
    enable = true;
    userKeys = [ "/home/${vars.username}/.ssh/id_ed25519" ];
  };

  users.users = lib.genAttrs hostUsers (username: {
    isNormalUser = true;
    description = "User ${username}";
    extraGroups = [
      "wheel"
      "networkmanager"
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

  # System packages - consolidated from individual nixos modules
  environment.systemPackages =
    with pkgs;
    [
      # Qt theme control tools for Stylix
      libsForQt5.qt5ct
      kdePackages.qt6ct
      # Custom packages
      # qwen-code disabled due to npm registry network errors (HTTP/2 framing layer issue)
      # (callPackage ../../home/development/qwen-code/default.nix { })
      nix-doc # Interactive Nix documentation tool
      # COSMIC desktop extensions
      cosmic-ext-applet-external-monitor-brightness
      cosmic-ext-applet-weather
      # Remote desktop
      rustdesk-flutter
      gnome-remote-desktop # For headless RDP service
      # Messaging applications
      karere # GTK4 WhatsApp client

      # Power management (from power.nix)
      cpupower-gui # GUI for CPU frequency scaling
      powertop # Power consumption analyzer
      lm_sensors # Hardware monitoring
      s-tui # Terminal UI stress test and monitoring tool
      htop # Process viewer with power info
      acpi # Command line battery info

      # Razer hardware support (from laptop.nix)
      polychromatic # GUI for Razer devices
      razergenie # Another Razer configuration tool

      # Login manager (from greetd.nix)
      tuigreet

      # Secure Boot management (from secure-boot.nix) - only when secure boot enabled
    ]
    ++ lib.optionals (config.boot.lanzaboote.enable or false) [
      sbctl # For managing Secure Boot keys
    ]
    # Every DE registered via services.xserver.desktopManager.*.enable —
    # needed so their share/wayland-sessions/*.desktop files land in
    # /run/current-system/sw/share/wayland-sessions where COSMIC Greeter
    # (and other display managers) actually look for session choices.
    ++ config.services.displayManager.sessionPackages;

  hardware.nvidia-container-toolkit.enable = vars.gpu == "nvidia";

  # Enable ZSA keyboard support (Moonlander, Planck EZ, etc.)
  hardware.keyboard.zsa.enable = true;

  # Windows app integration
  # programs.winboat.enable = true; # DISABLED: npm dependency error in nixpkgs (@electron/windows-sign)

  # Agenix identity configuration - specify where to find decryption keys
  age.identityPaths = [
    "/home/olafkfreund/.ssh/id_ed25519" # User key
    "/etc/ssh/ssh_host_ed25519_key" # Host key (Ed25519)
    "/etc/ssh/ssh_host_rsa_key" # Host key (RSA fallback)
  ];

  # Override GNOME Shell to remove problematic dark mode patch
  nixpkgs.overlays = [
    (_final: prev: {
      gnome-shell = prev.gnome-shell.overrideAttrs (old: {
        patches = builtins.filter (patch: !lib.hasSuffix "shell_remove_dark_mode.patch" (toString patch)) (
          old.patches or [ ]
        );
      });
    })
  ];

  nixpkgs.config = {
    allowBroken = true;
    permittedInsecurePackages = [
      "olm-3.2.16"
      "python3.12-youtube-dl-2021.12.17"
      "libsoup-2.74.3" # Temporary: Required by some GNOME packages until migration to libsoup-3
      "electron-35.7.5" # Temporary: Required until upstream packages migrate to newer electron
    ];
  };
  system.stateVersion = "25.11";
}
