{
  # User information
  username = "olafkfreund";
  fullName = "Olaf K-Freund";
  gitUsername = "olaffreund";
  gitEmail = "olaf.loken@gmail.com";
  gitHubToken = "";

  # Display configuration
  laptop_monitor = "monitor = eDP-1,1920x1080@120,0x0,1";
  external_monitor = "";

  # Hardware settings
  gpu = "intel";
  acceleration = "vaapi"; # Intel video acceleration

  # System groups
  userGroups = [
    "networkmanager"
    "openrazer"
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

  # Networking
  hostName = "samsung";
  nameservers = [ "1.1.1.1" "8.8.8.8" ];
  hostMappings = {
    "192.168.1.127" = "p510";
    "192.168.1.188" = "razer"; # Updated to current wired IP
    "192.168.1.97" = "p620";
    "192.168.1.246" = "hp";
    "192.168.1.222" = "dex5550";
    "192.168.1.90" = "samsung"; # This host
  };

  # Locale and time
  timezone = "Europe/London";
  locale = "en_GB.UTF-8";
  # Different settings for console and X server keyboard layouts
  keyboardLayouts = {
    console = "uk"; # For virtual console
    xserver = "gb"; # For X server and Wayland
  };

  # Theme settings
  theme = {
    scheme = "gruvbox-dark-medium";
    wallpaper = ./themes/orange-desert.jpg;
    cursor = {
      name = "Bibata-Modern-Ice";
      size = 26;
    };
    font = {
      mono = "JetBrainsMono Nerd Font";
      sans = "Noto Sans";
      serif = "Noto Serif";
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

  # Environment variables
  environmentVariables = {
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
    NIXPKGS_ALLOW_INSECURE = "1";
    NIXPKGS_ALLOW_UNFREE = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    KITTY_DISABLE_WAYLAND = "0";
    # Intel graphics optimization
    MESA_LOADER_DRIVER_OVERRIDE = "iris";
    INTEL_DEBUG = "norbc";
    LIBVA_DRIVER_NAME = "iHD";
  };

  # Service-specific configs
  services = {
    nfs = {
      enable = true;
      exports = "/extdisk         192.168.1.*(rw,fsid=0,no_subtree_check)";
    };
  };

  # Shared paths
  paths = {
    flakeDir = "/home/olafkfreund/.config/nixos";
    external_disk = "/extdisk";
  };
}
