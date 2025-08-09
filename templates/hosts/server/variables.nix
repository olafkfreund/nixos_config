# Server template variables.nix
# Edit these values to customize your server configuration
# This template is optimized for headless server deployments
{
  # === BASIC HOST CONFIGURATION ===
  hostName = "HOSTNAME"; # Replace with your server hostname
  userName = "USERNAME"; # Replace with your username
  userFullName = "FULL NAME"; # Replace with your full name
  userEmail = "user@example.com"; # Replace with your email
  githubUsername = "GITHUB_USERNAME"; # Replace with your GitHub username

  # === LOCALIZATION ===
  timezone = "Europe/London"; # Set your timezone
  locale = "en_GB.UTF-8"; # Set your locale

  # === SYSTEM ===
  stateVersion = "25.05"; # NixOS version
  headless = true; # Server is headless (no GUI)

  # === HARDWARE CONFIGURATION ===
  gpu = "none"; # Options: amd, nvidia, intel, none
  acceleration = "none"; # Options: rocm, cuda, vaapi, none

  # === NETWORK CONFIGURATION ===
  network = {
    localDomain = "home.freundcloud.com";
    fallbackDns = [ "192.168.1.222" "1.1.1.1" "8.8.8.8" ];

    # Open firewall ports for server services
    openPorts = {
      tcp = [ 22 80 443 ]; # SSH, HTTP, HTTPS by default
      udp = [ ]; # Add UDP ports as needed
    };

    # Static host mappings for local services
    hostMappings = {
      "192.168.1.100" = "HOSTNAME";
      # Add more host mappings as needed
    };

    # Network interface configuration (optional)
    interfaces = {
      # Example static IP configuration:
      # "enp3s0" = {
      #   ipv4.addresses = [{
      #     address = "192.168.1.100";
      #     prefixLength = 24;
      #   }];
      # };
    };
  };

  # === TAILSCALE VPN ===
  tailscale = {
    enable = true; # Enable Tailscale mesh VPN
    hostname = "HOSTNAME-server"; # Tailscale hostname
  };

  # === SSH CONFIGURATION ===
  sshPublicKeys = [
    # Add your SSH public keys here
    # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG... your-key@hostname"
  ];

  # === FEATURE FLAGS ===
  features = {
    # Development tools (minimal for servers)
    development = false; # Enable basic development tools

    # Virtualization
    virtualization = true; # Enable virtualization support
    docker = true; # Enable Docker
    podman = false; # Enable Podman (alternative to Docker)
    libvirt = false; # Enable KVM/QEMU virtualization
    lxc = false; # Enable LXC containers

    # Monitoring
    monitoring = {
      enable = true; # Enable monitoring
      mode = "client"; # Options: server, client
      serverHost = "dex5550"; # Monitoring server hostname
    };

    # AI providers (optional for servers)
    ai = {
      enable = false; # Enable AI providers
      defaultProvider = "anthropic"; # Default: anthropic, openai, gemini, ollama
      enableFallback = true; # Enable provider fallback
      openai = false; # Enable OpenAI API
      anthropic = false; # Enable Anthropic Claude API
      gemini = false; # Enable Google Gemini API
      ollama = false; # Enable local Ollama models
    };

    # Media server services
    mediaServer = {
      enable = false; # Enable media server features
      plex = false; # Enable Plex Media Server
      jellyfin = false; # Enable Jellyfin Media Server
      transmission = false; # Enable Transmission BitTorrent
      nzbget = false; # Enable NZBGet Usenet
      sonarr = false; # Enable Sonarr TV management
      radarr = false; # Enable Radarr movie management
    };

    # Database services
    database = {
      enable = false; # Enable database services
      postgresql = false; # Enable PostgreSQL
      mysql = false; # Enable MySQL/MariaDB
      redis = false; # Enable Redis
      mongodb = false; # Enable MongoDB
    };

    # Web services
    webServices = {
      enable = false; # Enable web services
      nginx = false; # Enable Nginx web server
      apache = false; # Enable Apache web server
      nodejs = false; # Enable Node.js runtime
    };
  };

  # === AUTO-UPDATE CONFIGURATION ===
  autoUpgrade = {
    enable = false; # Enable automatic system updates
    allowReboot = false; # Allow automatic reboots
    schedule = "04:00"; # Update schedule (daily at 4 AM)
  };

  # === NIX CONFIGURATION ===
  nix = {
    # Binary cache substituters
    substituters = [
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      # Add your custom binary cache if available
      # "http://p620:5000/"
    ];

    # Trusted public keys for binary caches
    trustedPublicKeys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  # === STORAGE CONFIGURATION ===
  storage = {
    # ZFS configuration (if using ZFS)
    zfs = {
      enable = false; # Enable ZFS support
      pools = [ ]; # ZFS pool names
    };

    # Backup configuration
    backup = {
      enable = true; # Enable backup services
      destinations = [ ]; # Backup destinations
      schedule = "daily"; # Backup schedule
    };
  };

  # === USER DIRECTORIES ===
  userDirs = {
    home = "/home/USERNAME";
    # Add more user-specific paths as needed
  };

  # === THEME CONFIGURATION (Minimal for servers) ===
  theme = {
    # Console theme only
    console = {
      font = "Lat2-Terminus16";
      colors = "dark";
    };
  };

  # === PERFORMANCE TUNING ===
  performance = {
    # CPU governor for servers
    cpuGovernor = "powersave"; # Options: performance, powersave, ondemand, conservative

    # Memory settings
    swappiness = 1; # Low swappiness for servers

    # I/O scheduler
    ioScheduler = "mq-deadline"; # Good for servers
  };

  # === SECURITY SETTINGS ===
  security = {
    # Firewall logging
    logFirewall = false; # Disable to reduce log spam

    # Fail2ban configuration
    fail2ban = {
      enable = true; # Enable intrusion prevention
      maxRetry = 3; # Max failed attempts
      banTime = 3600; # Ban duration in seconds
    };

    # Security hardening
    hardening = {
      enable = true; # Enable security hardening
      kernel = true; # Kernel hardening
      network = true; # Network hardening
    };
  };
}
