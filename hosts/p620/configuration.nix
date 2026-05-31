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
    ./nixos/aqc107-link-pin.nix # Pin Aquantia AQC107 to 1G to dodge AER flapping
    ./nixos/dns-fallback.nix # systemd-resolved with public DNS fallback (issue #564)
    ./nixos/tailscale-serve.nix # Tailscale Serve for /router (LiteLLM, Phase 2)
    ../common/nixos/i18n.nix
    ../common/nixos/hosts.nix
    ../common/nixos/envvar.nix
    ../common/nixos/host-class.nix
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
    ../../modules/services/skill-pool.nix # local skill-pool registry portal
    ../../modules/services/ollama.nix # local Ollama coding-model server (RX 7900 XTX, ROCm)
    ../../modules/services/litellm-router.nix # Anthropic-compat proxy → Ollama (Phase 2)
  ];
  host.class = "workstation";

  # Consolidated networking configuration
  networking = {
    # Set hostname from variables
    inherit (vars) hostName;

    # Choose networking profile: "desktop", "server", or "minimal"
    profile = "desktop"; # Switch to desktop profile for GNOME NetworkManager integration

    # Note: Tailscale is enabled via services.tailscale (built-in NixOS module)
    # Custom networking.tailscale module was removed during anti-pattern cleanup

    # NetworkManager DNS handoff to systemd-resolved configured in
    # ./nixos/dns-fallback.nix (issue #564).

    # Pin this host's own Tailscale MagicDNS name as a safety net in case the
    # tailscaled→resolved D-Bus push hasn't fired yet at boot (e.g. during
    # nixos-rebuild switch). Local dev tools whose auth callbacks redirect to
    # the tailnet hostname would otherwise time out.
    extraHosts = ''
      100.69.100.115 p620.tail833f7.ts.net
    '';

    # Firewall disabled - P620 is inside a secure network
    firewall.enable = lib.mkForce false;
  };

  # Tailscale VPN using built-in NixOS service
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both"; # Can route and accept routes
    openFirewall = true;
  };

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

  # Local Ollama coding-model server on RX 7900 XTX (loopback only, ROCm).
  # Phase 1 of docs/plans/2026-05-22-ollama-p620-litellm-design.md.
  # Defaults: qwen3.6:27b persistent + gemma4:26b on-demand (5min unload).
  # Reachable from same host only at http://127.0.0.1:11434; the LiteLLM
  # proxy (Phase 2) will be the Anthropic-compat front-end for Claude Code.
  # Model blobs land on /mnt/data (938GB ext4 disk) instead of root /.
  features.ollama-server = {
    enable = true;
    modelsDir = "/mnt/data/ollama/models";
    persistentModels = [ "qwen3:14b" ];
    onDemandModels = [ "qwen2.5-coder:14b" "gemma4:e4b" ];
  };

  # LiteLLM router — Anthropic-compat proxy fronting Ollama (Phase 2).
  # Loopback + tailscale0 + enp1s0 (LAN) reachable; global :4000 closed.
  # Master key stored in agenix (secrets/litellm-master-key.age).
  features.litellm-router = {
    enable = true;
    listenLanInterface = "enp1s0";
  };

  # Claude Code managed-settings baseline (read-only at /etc/claude-code).
  # Enables PARR hook + lets the router CLI inject apiKeyHelper (Phase 3).
  modules.programs.claude-code-managed = {
    enable = true;
    parrProtocol.enable = true;
  };

  # /use-ollama, /use-claude, /use-default slash commands + apiKeyHelper
  # that auto-selects router or Anthropic key based on ANTHROPIC_BASE_URL.
  modules.programs.claude-router-cli.enable = true;

  # AI production dashboard and load testing removed - were non-functional services consuming resources

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
      precommit = true; # Activates modules/development/pre-commit.nix — installs markdownlint, statix, taplo, yamllint, ruff, etc. system-wide.
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
      antigravity-cli = true;
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
      };

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
      neomutt.enable = false;
      ai.enable = true;
      ai.provider = "openai";
      notifications.enable = true;
      notifications.highPriorityOnly = true;
    };

    programs = {
      lazygit = true;
      thunderbird = false;
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

    # COSMIC disabled — sticking with GNOME only until COSMIC is more
    # production-ready. Module + packages parked under modules/desktop/cosmic.nix
    # and pkgs/cosmic-applets/ for easy re-enable.
    desktop.cosmic.enable = false;

    # Microsoft Intune Company Portal (custom package with version control)
    intune = {
      enable = false; # Disabled - no longer needed
      autoStart = false; # Manual launch - start from application menu as needed
      enableDesktopIntegration = true;
    };
  };

  # Display manager: GDM (was previously delegated to cosmic-greeter by the
  # cosmic module; the unified DM module defaults to "none" without it).
  # NOTE: must live at top-level, NOT inside the features = {...} block above —
  # the option path is `desktop.displayManager`, not `features.desktop.displayManager`.
  desktop.displayManager.backend = "gdm";

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
    # Run user services even when not logged in so headless user units
    # (e.g. the GNOME Remote Desktop headless service wired by
    # modules/desktop/gnome-remote-desktop.nix) keep working at boot
    # before someone logs in via TTY/SSH/desktop session.
    linger = true;
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
      displayManager.xserverArgs = [
        "-nolisten tcp"
        "-dpi 96"
      ];
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
    customPkgs.rmux # Rust tmux-compatible multiplexer + typed SDK for agent orchestration
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
  #
  # /mnt/media is hosted on p510 over NFSv3. The previous default of
  # `hard` mount semantics meant every process touching this path
  # (file managers, COSMIC indexers, mpd, etc.) blocked indefinitely
  # whenever the link to p510 hiccuped. The on-board AQC107 has been
  # emitting bursts of corrected PCIe AER errors, which manifested as
  # 50%+ IO-pressure stalls and a sluggish desktop.
  #
  # New options:
  #   soft+timeo+retrans  - fail an RPC after 5 s × 3 instead of blocking forever
  #   bg                  - background-mount on first attempt; don't stall boot
  #   noauto+automount    - mount on first access, not at boot
  #   idle-timeout        - auto-unmount after 5 min idle so a flap can't
  #                         poison long-running sessions
  #   rsize/wsize         - 1 MiB I/O units (matches what the server already serves)
  #   noatime             - skip atime updates over the wire
  #
  # Read-mostly media share, so `soft` is acceptable here - data
  # corruption from a half-finished write is not in scope.
  fileSystems."/mnt/media" = {
    device = "p510.lan:/mnt/media";
    fsType = "nfs";
    options = [
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=300"
      "soft"
      "timeo=50"
      "retrans=3"
      "bg"
      "noatime"
      "rsize=1048576"
      "wsize=1048576"
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
  # programs.winboat.enable = true; # DISABLED: Go 1.26 cross-compilation broken with mingw32 GCC 15

  # Package configurations
  nixpkgs.config = {
    allowBroken = true;
    permittedInsecurePackages = [
      "olm-3.2.16"
      "python3.12-youtube-dl-2021.12.17"
      "python3.13-youtube-dl-2021.12.17" # newsboat (RSS reader) pulls youtube-dl for URL extraction
      "libsoup-2.74.3" # Temporary: Required by some GNOME packages until migration to libsoup-3
      "electron-35.7.5" # Temporary: Required until upstream packages migrate to newer electron
    ];
  };
}
