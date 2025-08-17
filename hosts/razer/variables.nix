{ }:
let
  # Import shared variables and NVIDIA hardware profile
  sharedVars = import ../common/shared-variables.nix;
  hardwareProfile = import ../common/hardware-profiles/nvidia-gpu.nix;

  # Razer-specific overrides
  hostOverrides = {
    hostName = "razer";
    nameservers = [ ]; # Use DHCP-provided DNS servers

    # Razer laptop display configuration
    laptop_monitor = "monitor = eDP-1,1920x1080@120,0x0,1";
    external_monitor = "";

    # Razer-specific theme wallpaper
    wallpaper = ./themes/orange-desert.jpg;

    # Razer-specific user groups (OpenRazer support)
    extraUserGroups = [
      "openrazer" # Razer hardware support
      "libvirtd" # Virtualization
      "lxd" # LXD containers
      "incus-admin" # Incus containers
      "scanner" # Scanning support
      "lp" # Printing support
    ];

    # NFS server configuration for external disk sharing
    nfsConfig = {
      enable = true;
      exports = "/extdisk         192.168.1.*(rw,fsid=0,no_subtree_check)";
    };

    # External disk path
    externalDiskPath = "/extdisk";
  };

  # Merge shared variables with hardware profile and host overrides
  user = sharedVars.user // { };
  localization = sharedVars.localization // { };

  # Merge network configuration
  network = sharedVars.network // {
    inherit (hostOverrides) hostName nameservers;
  };

  # Hardware configuration from NVIDIA profile + razer-specific environment
  hardware = {
    inherit (hardwareProfile) gpu acceleration videoDrivers;
    extraEnvironment = hardwareProfile.extraEnvironment;
  };

  # Theme configuration with razer wallpaper override
  theme = sharedVars.baseTheme // {
    wallpaper = hostOverrides.wallpaper;
  };

  # Environment variables: shared + hardware profile + razer-specific
  environmentVariables = sharedVars.baseEnvironment //
    hardwareProfile.extraEnvironment // {
    # Razer laptop-specific optimizations
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    KITTY_DISABLE_WAYLAND = "0";
  };

  # User groups: shared + hardware profile + razer-specific
  userGroups = sharedVars.baseUserGroups ++
    (hardwareProfile.extraGroups or [ ]) ++
    hostOverrides.extraUserGroups;

  # Services configuration
  services = {
    nfs = hostOverrides.nfsConfig;
  };

  # Paths configuration
  paths = sharedVars.basePaths // {
    external_disk = hostOverrides.externalDiskPath;
  };

in
{
  # User information (shared across all hosts)
  inherit (user) username fullName gitUsername gitEmail gitHubToken;

  # Display configuration (razer-specific)
  inherit (hostOverrides) laptop_monitor external_monitor;

  # Hardware configuration (NVIDIA profile)
  inherit (hardware) gpu acceleration;

  # User groups (merged: shared + nvidia + razer-specific)
  inherit userGroups;

  # Network configuration (shared base + razer overrides)
  inherit (network) hostName nameservers;
  hostMappings = network.hostMappings;

  # Localization (shared across all hosts)
  inherit (localization) timezone locale keyboardLayouts;

  # Theme configuration (shared + razer wallpaper)
  inherit theme;

  # Environment variables (shared + nvidia + razer-specific)
  inherit environmentVariables;

  # Services configuration (razer-specific)
  inherit services;

  # Paths configuration (shared + razer external disk)
  inherit paths;
}
