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
  imports =
    hostTypes.workstation.imports
    ++ [
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
      ./themes/stylix.nix

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

    # Firewall configuration for SSH and remote desktop
    firewall = {
      allowedTCPPorts = [
        22 # SSH port from hardening config
        3389 # RDP port for GNOME Remote Desktop
        5900 # VNC port for GNOME Remote Desktop
      ];

      # Extra rules for SSH protection
      extraCommands = ''
        # Rate limiting for SSH connections
        iptables -I INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set --name SSH_LIMIT
        iptables -I INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 --name SSH_LIMIT -j DROP

        # Allow established SSH connections
        iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

        # Log dropped SSH attempts
        iptables -A INPUT -p tcp --dport 22 -j LOG --log-prefix "SSH-DROP: " --log-level 4
      '';

      extraStopCommands = ''
        # Clean up SSH rules
        iptables -D INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set --name SSH_LIMIT 2>/dev/null || true
        iptables -D INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 --name SSH_LIMIT -j DROP 2>/dev/null || true
      '';
    };
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

  # Enable MCP (Model Context Protocol) servers for AI integration
  features.ai.mcp = {
    enable = true;
    # Enable Obsidian MCP server for knowledge base access
    obsidian = {
      enable = true;
      vaultPath = "/home/olafkfreund/Documents/Caliti";
    };
    # Enable additional MCP servers
    servers = {
      grafana = true; # Integration with monitoring stack
      terraform = true; # Infrastructure as Code support
    };
  };

  # Re-enable Claude Desktop with local package
  # features.ai.claude-desktop = true;

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

  # AI production dashboard and load testing removed - were non-functional services consuming resources

  # Enable NixOS package monitoring tools
  tools.nixpkgs-monitors = {
    enable = true;
    installAll = true;
  };

  # AI alerting removed - was non-functional, handled by DEX5550 monitoring server via Prometheus/Grafana/Alertmanager

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
      droidcam = true;
    };

    # Enable QuickShell for testing (experimental - runs alongside Waybar)
    quickshell = {
      enable = true;
    };

    # Enable COSMIC Desktop with all applications
    desktop.cosmic = {
      enable = true;
      useCosmicGreeter = false; # Disabled due to libEGL.so.1 bug (nixpkgs #464392)
      defaultSession = true; # Set COSMIC as default session
      installAllApps = true;
      disableOsd = true; # Workaround for polkit agent crashes in COSMIC beta
    };

    # Microsoft Intune Company Portal (custom package with version control)
    intune = {
      enable = true;
      autoStart = false; # Manual launch - start from application menu as needed
      enableDesktopIntegration = true;
    };
  };

  # Citrix Workspace for client project remote access
  services.citrix-workspace = {
    enable = true;
    acceptLicense = true; # Accept Citrix EULA for client project work
  };

  # Use GDM instead of COSMIC greeter until bug is fixed
  services.displayManager.gdm.enable = true;

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

  # Create system users for all host users + gitlab-runner
  users.users = (lib.genAttrs hostUsers (username: {
    isNormalUser = true;
    description = "User ${username}";
    extraGroups = [ "wheel" "networkmanager" "render" ];
    shell = pkgs.zsh;
    # Only use secret-managed password if the secret exists
    hashedPasswordFile =
      lib.mkIf
        (config.modules.security.secrets.enable
          && builtins.hasAttr "user-password-${username}" config.age.secrets)
        config.age.secrets."user-password-${username}".path;
  })) // {
    # GitLab Runner user (for manual runner registration)
    gitlab-runner = {
      isSystemUser = true;
      group = "gitlab-runner";
      home = "/var/lib/gitlab-runner";
      createHome = true;
      description = "GitLab Runner user";
      extraGroups = [ "docker" ];
    };
  };
  users.groups.gitlab-runner = { };

  # Remove duplicate user configuration - use the one above that handles all hostUsers
  # users.users.${vars.username} is now handled by the genAttrs above

  # Consolidated services configuration
  services = {
    # Nixai
    nixai = {
      enable = true;
      mcp.enable = true;
    };

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

    # Nix-serve configuration
    nix-serve = {
      enable = true;
      port = 5000; # Default port for nix-serve
      secretKeyFile = "/etc/nix/secret-key"; # Path to the secret key file
      openFirewall = true; # Automatically open the firewall port
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

    # GitLab Runner for CI/CD (manually registered runners)
    # Runners are registered using: ./scripts/setup-gitlab-runner.sh
    # Disabled NixOS module - using native gitlab-runner service instead
    # gitlab-runner-local.enable = false;

    # Hardware-specific configurations
    udev = {
      packages = [ pkgs.via ];
      extraRules = builtins.concatStringsSep "\n" [
        ''ACTION=="add", SUBSYSTEM=="video4linux", DRIVERS=="uvcvideo", RUN+="${pkgs.v4l-utils}/bin/v4l2-ctl --set-ctrl=power_line_frequency=1"''
        ''KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", TAG+="uaccess"''
      ];
    };
  };

  # GitLab Runner systemd service (outside services block)
  systemd.services.gitlab-runner = {
    description = "GitLab Runner";
    after = [ "network.target" "docker.service" ];
    wants = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "gitlab-runner";
      Group = "gitlab-runner";
      WorkingDirectory = "/var/lib/gitlab-runner";
      ExecStart = "${pkgs.gitlab-runner}/bin/gitlab-runner run --config /etc/gitlab-runner/config.toml --working-directory /var/lib/gitlab-runner";
      Restart = "always";
      RestartSec = 10;

      # Security hardening
      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/gitlab-runner" "/etc/gitlab-runner" ];

      # Resource limits
      MemoryMax = "4G";
      TasksMax = 1000;
    };

    preStart = ''
            # Create directories if they don't exist
            mkdir -p /etc/gitlab-runner
            mkdir -p /var/lib/gitlab-runner

            # Only create minimal config if it doesn't exist
            if [ ! -f /etc/gitlab-runner/config.toml ]; then
              cat > /etc/gitlab-runner/config.toml <<EOF
      concurrent = 4
      check_interval = 0
      log_level = "info"

      [session_server]
        session_timeout = 1800
      EOF
            fi

            # Set proper permissions
            chown -R gitlab-runner:gitlab-runner /etc/gitlab-runner
            chown -R gitlab-runner:gitlab-runner /var/lib/gitlab-runner
            chmod 700 /var/lib/gitlab-runner
            chmod 600 /etc/gitlab-runner/config.toml || true
    '';
  };

  # System packages
  environment.systemPackages = with pkgs; [
    gitlab-runner # For manual runner registration
    rocmPackages.llvm.libcxx
    via
    looking-glass-client
    scream
    vim
    wally-cli
    # Qt theme control tools for Stylix
    libsForQt5.qt5ct
    kdePackages.qt6ct
    # Custom qwen-code package
    (callPackage ../../home/development/qwen-code/default.nix { })
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
    device = "192.168.1.127:/mnt/media";
    fsType = "nfs";
    options = [ "x-systemd.automount" "noauto" ];
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

  # Nix configuration
  nix.settings.allowed-users = [ "nix-serve" ];

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
          (patch:
            !(builtins.match ".*shell_remove_dark_mode.*" (toString patch) != null)
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
