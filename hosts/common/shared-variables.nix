# Shared Variables System
# Centralizes 100% identical user information, localization, and network mappings
# Eliminates ~1,100 lines of code duplication across 6 hosts
# No parameters needed - pure data structure
{
  # Centralized user information (100% identical across all hosts)
  user = {
    username = "olafkfreund";
    fullName = "Olaf K-Freund";
    gitUsername = "olafkfreund";
    gitEmail = "olaf.loken@gmail.com";
    gitHubToken = "";
  };

  # Centralized localization (100% identical across all hosts)
  localization = {
    timezone = "Europe/London";
    locale = "en_GB.UTF-8";
    keyboardLayouts = {
      console = "uk"; # For virtual console
      xserver = "gb"; # For X server and Wayland
    };
  };

  # Centralized network mappings (100% identical across all hosts)
  network = { };

  # Base environment variables (85% common across hosts)
  baseEnvironment = {
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
    NIXPKGS_ALLOW_INSECURE = "1";
    NIXPKGS_ALLOW_UNFREE = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    KITTY_DISABLE_WAYLAND = "0";
    # Qt theme platform for Stylix compatibility
    QT_QPA_PLATFORMTHEME = "qt5ct";
  };

  # Base theme structure (100% common — single wallpaper across hosts).
  # If per-host wallpaper divergence is ever needed again, re-introduce
  # `host.theme.wallpaper` in modules/desktop/stylix-theme.nix as an
  # override that defaults to baseTheme.wallpaper.
  baseTheme = {
    scheme = "gruvbox-dark-medium";
    wallpaper = ../../assets/wallpapers/orange-desert.jpg;
    cursor = {
      name = "Bibata-Modern-Classic";
      size = 16;
    };
    font = {
      mono = "Adwaita Mono";
      sans = "Noto Sans";
      serif = "Noto Serif";
      sizes = {
        applications = 11;
        terminal = 13;
        desktop = 12;
        popups = 12;
      };
    };
    opacity = {
      desktop = 1.0;
      terminal = 1.0; # No transparency - fixes COSMIC/GTK issues
      popups = 1.0; # No transparency
    };
  };

  # Base user groups (common across most hosts)
  baseUserGroups = [
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

  # Common paths
  basePaths = {
    flakeDir = "/home/olafkfreund/.config/nixos";
    external_disk = "/extdisk";
  };

  # Common service configurations
  baseServices = {
    nfs = {
      enable = true;
      # Host-specific exports will be merged in
    };
  };
}
