{
  # User information - CUSTOMIZE THESE
  username = "USERNAME";  # CHANGE: Your username
  fullName = "FULL NAME";  # CHANGE: Your full name
  gitUsername = "GITHUB_USERNAME";  # CHANGE: Your GitHub username
  gitEmail = "user@example.com";  # CHANGE: Your email address
  gitHubToken = "";

  # Display configuration - CUSTOMIZE FOR YOUR MONITORS
  # Single monitor setup
  laptop_monitor = "";
  external_monitor = "monitor = DP-1,1920x1080@60,0x0,1";  # CHANGE: Your monitor specs
  
  # Dual monitor example:
  # laptop_monitor = "monitor = DP-2,1920x1080@60,1920x0,1";
  # external_monitor = "monitor = DP-1,1920x1080@60,0x0,1";
  
  # High-DPI example:
  # external_monitor = "monitor = DP-1,3840x2160@120,0x0,1.5";

  # Hardware settings - CHOOSE YOUR GPU TYPE
  gpu = "nvidia";  # OPTIONS: "amd", "nvidia", "intel", "none"
  acceleration = "cuda";  # OPTIONS: "cuda" (nvidia), "rocm" (amd), "none"

  # System groups - Usually don't need to change
  userGroups = [
    "networkmanager"
    "libvirtd" 
    "wheel"
    "docker"
    "podman"
    "video"
    "scanner"
    "lp"
    "lxd"
    "incus-admin"
  ];

  # Networking - CUSTOMIZE FOR YOUR NETWORK
  hostName = "HOSTNAME";  # CHANGE: Your hostname
  nameservers = [];  # Use DHCP-provided DNS servers
  hostMappings = {
    # CHANGE: Add your network hosts
    "192.168.1.100" = "HOSTNAME";  # This host
    "192.168.1.127" = "p510";  # Example: media server
    "192.168.1.222" = "dex5550";  # Example: monitoring server
    # Add more hosts as needed
  };

  # Locale and time - CUSTOMIZE FOR YOUR LOCATION
  timezone = "Europe/London";  # CHANGE: Your timezone
  locale = "en_GB.UTF-8";  # CHANGE: Your locale
  
  # Keyboard layouts
  keyboardLayouts = {
    console = "us";  # CHANGE: Console keyboard layout
    xserver = "us";  # CHANGE: X server keyboard layout
  };

  # Theme settings - CUSTOMIZE APPEARANCE
  theme = {
    scheme = "gruvbox-dark-medium";  # OPTIONS: "gruvbox-dark-medium", "gruvbox-light-medium", etc.
    wallpaper = ./themes/default-wallpaper.jpg;  # CHANGE: Your wallpaper
    cursor = {
      name = "Bibata-Modern-Ice";  # Cursor theme
      size = 24;  # Cursor size
    };
    font = {
      mono = "JetBrainsMono Nerd Font";  # Monospace font
      sans = "Noto Sans";  # Sans-serif font
      serif = "Noto Serif";  # Serif font
      sizes = {
        applications = 12;
        terminal = 13;
        desktop = 12;
        popups = 12;
      };
    };
    opacity = {
      desktop = 1.0;
      terminal = 0.95;
      popups = 0.95;
    };
  };

  # Environment variables - GPU SPECIFIC
  environmentVariables = {
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
    NIXPKGS_ALLOW_INSECURE = "1";
    NIXPKGS_ALLOW_UNFREE = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    KITTY_DISABLE_WAYLAND = "0";
    
    # GPU-specific variables
    # For AMD GPUs:
    # LIBVA_DRIVER_NAME = "radeonsi";
    # For NVIDIA GPUs:
    # LIBVA_DRIVER_NAME = "nvidia";
    # For Intel GPUs:
    # LIBVA_DRIVER_NAME = "iHD";
  };

  # Service-specific configs - OPTIONAL
  services = {
    nfs = {
      enable = false;  # Set to true if you want to share files
      exports = "/shared/folder         192.168.1.*(rw,fsid=0,no_subtree_check)";
    };
    
    # Media server integration (optional)
    media = {
      enable = false;  # Set to true if this host serves media
      plexServer = false;
      minidlna = false;
    };
    
    # Development services (optional)
    development = {
      enable = true;
      postgresql = false;  # Set to true if you need local database
      redis = false;       # Set to true if you need Redis
      elasticsearch = false; # Set to true if you need Elasticsearch
    };
  };

  # Shared paths
  paths = {
    flakeDir = "/home/USERNAME/.config/nixos";  # CHANGE: Path to this flake
    dataDir = "/home/USERNAME/data";  # CHANGE: Your data directory
    projectsDir = "/home/USERNAME/projects";  # CHANGE: Your projects directory
  };

  # Performance tuning profiles - CUSTOMIZE FOR YOUR USE CASE
  performance = {
    # Performance profiles: "performance", "balanced", "efficiency"
    cpuProfile = "performance";     # High performance for workstation
    networkProfile = "balanced";   # Balanced network performance
    storageProfile = "performance"; # Fast storage for development
    
    # Resource limits
    maxCpuCores = 0;  # 0 = use all cores
    maxMemoryGB = 0;  # 0 = use all memory
    
    # Gaming optimizations
    gaming = {
      enable = true;  # Set to false for work-focused systems
      gamemode = true;
      steam = true;
      lutris = true;
    };
  };

  # Security settings
  security = {
    sshHardening = true;
    fail2ban = true;
    firewall = true;
    apparmor = false;  # Set to true for additional security
    auditd = false;    # Set to true for audit logging
  };

  # Monitoring configuration
  monitoring = {
    enable = true;
    mode = "client";  # "client" sends to monitoring server, "server" runs monitoring stack
    serverHost = "dex5550";  # CHANGE: Your monitoring server hostname
    
    # Metrics to collect
    metrics = {
      system = true;
      gpu = true;     # GPU metrics
      ai = true;      # AI/ML metrics
      docker = true;  # Container metrics
      network = true; # Network metrics
    };
  };

  # AI configuration
  ai = {
    enable = true;
    defaultProvider = "anthropic";  # OPTIONS: "openai", "anthropic", "gemini", "ollama"
    
    providers = {
      openai = true;     # Requires API key
      anthropic = true;  # Requires API key
      gemini = true;     # Requires API key
      ollama = true;     # Local inference, no API key needed
    };
    
    # Local AI configuration
    ollama = {
      enable = true;
      models = [
        "llama3.2"
        "mistral"
        "qwen2.5-coder"
      ];
      enableRag = false;  # Enable for document search
    };
  };

  # Backup configuration (optional)
  backup = {
    enable = false;  # Set to true to enable backups
    destinations = [
      # "/mnt/backup"  # Local backup
      # "user@backup-server:/backups"  # Remote backup
    ];
    schedule = "daily";  # "hourly", "daily", "weekly"
    retention = "30d";   # Keep backups for 30 days
  };
}