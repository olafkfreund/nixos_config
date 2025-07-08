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
    ./nixos/nvidia.nix
    ./nixos/i18n.nix
    ./nixos/hosts.nix
    ./nixos/envvar.nix
    ./nixos/greetd.nix
    ./nixos/cpu.nix
    ./nixos/laptop.nix
    ./nixos/memory.nix
    ./themes/stylix.nix
    ../../modules/default.nix
    ../../modules/development/default.nix
    ../common/hyprland.nix
    ../../modules/security/secrets.nix
    ../../modules/secrets/api-keys.nix
    ../../modules/containers/docker.nix
  ];

  # Set hostname from variables
  networking.hostName = vars.hostName;

  #Nixai
  services.nixai = {
    enable = true;
    mcp.enable = true;
  };

  # Choose networking profile: "desktop", "server", or "minimal"
  networking.profile = "desktop";

  # Configure AI providers directly
  ai.providers = {
    enable = true;
    defaultProvider = "anthropic";
    enableFallback = true;
    
    # Enable specific providers
    openai.enable = true;
    anthropic.enable = true;
    gemini.enable = true;
    ollama.enable = true;
  };

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
      tailscale = true;
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
      webcam = true;
      print = true;
    };

    media = {
      droidcam = true;
    };

    # Monitoring configuration - Razer as client
    monitoring = {
      enable = true;
      mode = "client";  # Monitored by dex5550
      serverHost = "dex5550";
      
      features = {
        nodeExporter = true;
        nixosMetrics = true;
        alerting = false;  # Only server handles alerting
      };
    };
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

  # IDIOT-PROOF DNS CONFIGURATION: Prevent Tailscale from breaking DNS
  # Force Tailscale to NEVER manage DNS to avoid conflicts
  vpn.tailscale = {
    enable = true;
    acceptDns = lib.mkForce false; # NEVER let Tailscale touch DNS
    netfilterMode = "off"; # Safer for laptops
  };

  # Keep secure DNS but ensure it doesn't conflict
  services.secure-dns = {
    enable = true;
    dnssec = "true";
    useStubResolver = true; # Ensure stub resolver is used
    networkManagerIntegration = true; # Ensure NM integration
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

  # CRITICAL: DNS Resolution Fix for Tailscale
  # Ensure proper service ordering to prevent DNS conflicts
  systemd.services = {
    # Disable network wait services to improve boot time
    NetworkManager-wait-online.enable = lib.mkForce false;
    
    # Make sure Tailscale starts AFTER DNS is properly configured
    tailscaled = {
      after = [ "network.target" "NetworkManager.service" "systemd-resolved.service" ];
      wants = [ "network.target" ];
      requires = [ "network-online.target" ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };
  };

  # Additional DNS conflict prevention
  networking.resolvconf.dnsExtensionMechanism = false;
  
  # FORCE systemd-resolved to manage resolv.conf properly
  networking.useHostResolvConf = lib.mkForce false;
  
  # Ensure proper DNS resolution order
  systemd.services.systemd-resolved = {
    wantedBy = ["multi-user.target"];
    before = ["network.target" "NetworkManager.service"];
    serviceConfig = {
      Restart = lib.mkForce "always";
      RestartSec = lib.mkForce "5s";
    };
  };
  
  # Create a persistent resolv.conf link service
  systemd.services.fix-resolv-conf = {
    description = "Fix resolv.conf link to systemd-resolved";
    after = ["systemd-resolved.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "fix-resolv-conf" ''
        # Remove existing resolv.conf
        rm -f /etc/resolv.conf
        # Create proper symlink to systemd-resolved
        ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
        # Ensure systemd-resolved is using our configuration
        systemctl restart systemd-resolved || true
      '';
    };
  };

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
