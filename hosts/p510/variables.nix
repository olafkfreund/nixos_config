{ }:
let
  # Import shared variables and NVIDIA hardware profile
  sharedVars = import ../common/shared-variables.nix;
  hardwareProfile = import ../common/hardware-profiles/nvidia-gpu.nix;

  # P510-specific overrides
  hostOverrides = {
    hostName = "p510";
    nameservers = [ ]; # Use DHCP-provided DNS servers

    # P510 server display configuration (single 4K external monitor)
    laptop_monitor = "";
    external_monitor = "monitor = DP-2,3840x2160@30,0x0,1.5";

    # P510-specific theme wallpaper
    wallpaper = ./themes/orange-desert.jpg;

    # P510-specific service configuration (media server)
    nfsConfig = {
      enable = true;
      exports = "/mnt/data         192.168.1.*(rw,fsid=0,no_subtree_check)";
    };

    # P510 external disk path for media server
    externalDiskPath = "/mnt/data";
  };

  # Merge shared variables with hardware profile and host overrides
  user = sharedVars.user // { };
  localization = sharedVars.localization // { };

  # Merge network configuration
  network = sharedVars.network // {
    inherit (hostOverrides) hostName nameservers;
  };

  # Hardware configuration from NVIDIA profile
  hardware = {
    inherit (hardwareProfile) gpu acceleration videoDrivers;
    extraEnvironment = hardwareProfile.extraEnvironment;
  };

  # Theme configuration with P510 wallpaper override
  theme = sharedVars.baseTheme // {
    wallpaper = hostOverrides.wallpaper;
  };

  # Environment variables: shared + hardware profile + P510-specific
  environmentVariables = sharedVars.baseEnvironment //
    hardwareProfile.extraEnvironment // {
    # P510 server-specific optimizations (same as shared for now)
  };

  # User groups: shared + hardware profile (no P510-specific additions)
  userGroups = sharedVars.baseUserGroups ++
    (hardwareProfile.extraGroups or [ ]);

  # Services configuration
  services = {
    nfs = hostOverrides.nfsConfig;
  };

  # Paths configuration with P510 media server paths
  paths = sharedVars.basePaths // {
    external_disk = hostOverrides.externalDiskPath;
  };

in
{
  # User information (shared across all hosts)
  inherit (user) username fullName gitUsername gitEmail gitHubToken;

  # Display configuration (P510-specific server setup)
  inherit (hostOverrides) laptop_monitor external_monitor;

  # Hardware configuration (NVIDIA profile)
  inherit (hardware) gpu acceleration;

  # User groups (merged: shared + nvidia)
  inherit userGroups;

  # Network configuration (shared base + P510 overrides)
  inherit (network) hostName nameservers;
  hostMappings = network.hostMappings;

  # Localization (shared across all hosts)
  inherit (localization) timezone locale keyboardLayouts;

  # Theme configuration (shared + P510 wallpaper)
  inherit theme;

  # Environment variables (shared + nvidia)
  inherit environmentVariables;

  # Services configuration (P510-specific media server)
  inherit services;

  # Paths configuration (shared + P510 media paths)
  inherit paths;
}
