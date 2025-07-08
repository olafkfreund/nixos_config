{
  # User information
  username = "olafkfreund";
  fullName = "Olaf K-Freund";
  gitUsername = "olaffreund";
  gitEmail = "olaf.loken@gmail.com";
  gitHubToken = "";

  # Display configuration
  laptop_monitor = "monitor = ,preferred,auto,1";
  external_monitor = "monitor = HEADLESS-1,3840x2160@30,0x0,1.5";

  # Hardware settings
  gpu = "modesetting";
  acceleration = ""; # For ollama - Default to empty for this machine

  # System groups - server optimized
  userGroups = [
    "networkmanager"
    "libvirtd"
    "wheel"
    "docker"
    "podman"
    "lxd"
    "incus-admin"
  ];

  # Networking
  hostName = "dex5550";
  nameservers = ["1.1.1.1" "8.8.8.8"];
  hostMappings = {
    "192.168.1.127" = "p510";
    "192.168.1.96" = "razer";
    "192.168.1.97" = "p620";
    "192.168.1.246" = "hp";
    "192.168.1.222" = "dex5550";
  };

  # Locale and time
  timezone = "Europe/London";
  locale = "en_GB.UTF-8";
  # Different settings for console and X server keyboard layouts
  keyboardLayouts = {
    console = "uk"; # For virtual console
    xserver = "gb"; # For X server and Wayland
  };

  # No theme settings needed for server configuration

  # Environment variables - server optimized
  environmentVariables = {
    NIXPKGS_ALLOW_INSECURE = "1";
    NIXPKGS_ALLOW_UNFREE = "1";
  };

  # Service-specific configs
  services = {
    nfs = {
      enable = false;
      exports = "";
    };
  };

  # Shared paths
  paths = {
    flakeDir = "/home/olafkfreund/.config/nixos";
    external_disk = "/mnt/data";
  };
}
