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
  imports =
    hostTypes.laptop.imports
    ++ [
      # Hardware-specific imports
      ./nixos/hardware-configuration.nix
      ./nixos/screens.nix
      ./nixos/power.nix
      ./nixos/boot.nix
      # ./nixos/secure-boot.nix # Secure Boot enabled with lanzaboote
      ./nixos/nvidia.nix
      ../common/nixos/i18n.nix
      ../common/nixos/hosts.nix
      ../common/nixos/envvar.nix
      ./nixos/cpu.nix
      ./nixos/laptop.nix
      ./nixos/memory.nix
      ./themes/stylix.nix

      # Razer-specific additional modules
      ../../modules/development/default.nix
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
    nameservers = [ "192.168.1.222" "1.1.1.1" "8.8.8.8" ];

    # Firewall configuration for remote desktop moved to features.gnome-remote-desktop
  };

  # Tailscale VPN using built-in NixOS service
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client"; # Accept routes from other nodes
    openFirewall = true;
  };

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
      ollama = true;
      gemini-cli = true;
    };

    programs = {
      lazygit = true;
      thunderbird = true;
      obsidian = true;
      office = true;
      webcam = false; # Disabled due to v4l2loopback build failures
      print = true;
    };

    media = {
      droidcam = false; # Disabled due to v4l2loopback dependency
    };

    # COSMIC Desktop with COSMIC Greeter enabled
    desktop.cosmic = {
      enable = true;
      useCosmicGreeter = false; # Disabled due to libEGL.so.1 bug (nixpkgs #464392)
      defaultSession = true;
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
    enable = true; # Enabled with version 25.08.10.111
    acceptLicense = true; # Accept Citrix EULA for client project work
  };

  # Use GDM instead of COSMIC greeter until bug is fixed
  # Note: Using new services.displayManager.gdm.enable below

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
    # Nixai
    nixai = {
      enable = true;
      mcp.enable = true;
    };

    # GNOME Remote Desktop configuration moved to features.gnome-remote-desktop

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

  # Display manager - Use GDM (COSMIC greeter disabled due to libEGL.so.1 bug)
  services.displayManager.gdm.enable = true;

  # Hardware and service specific configurations
  services = {
    playerctld.enable = true;
    fwupd.enable = true;
    ollama.package = pkgs.ollama-cuda; # NVIDIA GPU acceleration
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

  # System packages - consolidated from individual nixos modules
  environment.systemPackages = with pkgs;
    [
      # Qt theme control tools for Stylix
      libsForQt5.qt5ct
      kdePackages.qt6ct
      # Custom packages
      (callPackage ../../home/development/qwen-code/default.nix { })

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
    ];

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
        patches = builtins.filter
          (patch: !lib.hasSuffix "shell_remove_dark_mode.patch" (toString patch))
          (old.patches or [ ]);
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
