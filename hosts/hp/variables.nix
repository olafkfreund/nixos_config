{ }:
let
  # Import shared variables and NVIDIA hardware profile
  sharedVars = import ../common/shared-variables.nix;
  hardwareProfile = import ../common/hardware-profiles/nvidia-gpu.nix;

  # HP-specific overrides
  hostOverrides = {
    hostName = "hp";
    nameservers = [ "1.1.1.1" "8.8.8.8" ]; # External DNS

    # HP display configuration (headless with virtual monitor)
    laptop_monitor = "monitor = ,preferred,auto,1";
    external_monitor = "monitor = HEADLESS-1,3840x2160@30,0x0,1.5";

    # HP-specific theme wallpaper
    wallpaper = ./themes/orange-desert.jpg;

    # HP-specific service configuration (NFS enabled)
    nfsConfig = {
      enable = true;
      exports = "/mnt/data         192.168.1.*(rw,fsid=0,no_subtree_check)";
    };

    # HP external disk path
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

  # Theme configuration with HP wallpaper override
  theme = sharedVars.baseTheme // {
    wallpaper = hostOverrides.wallpaper;
  };

  # Environment variables: shared + hardware profile
  environmentVariables = sharedVars.baseEnvironment //
    hardwareProfile.extraEnvironment;

  # User groups: shared + hardware profile
  userGroups = sharedVars.baseUserGroups ++
    (hardwareProfile.extraGroups or [ ]);

  # Services configuration
  services = {
    nfs = hostOverrides.nfsConfig;
  };

  # Paths configuration with HP external disk
  paths = sharedVars.basePaths // {
    external_disk = hostOverrides.externalDiskPath;
  };

in
{
  # User information (shared across all hosts)
  inherit (user) username fullName gitUsername gitEmail gitHubToken;

  # Display configuration (HP-specific headless setup)
  inherit (hostOverrides) laptop_monitor external_monitor;

  # Hardware configuration (NVIDIA profile)
  inherit (hardware) gpu acceleration;

  # User groups (merged: shared + nvidia)
  inherit userGroups;

  # Network configuration (shared base + HP overrides)
  inherit (network) hostName nameservers;
  hostMappings = network.hostMappings;

  # Localization (shared across all hosts)
  inherit (localization) timezone locale keyboardLayouts;

  # Theme configuration (shared + HP wallpaper)
  inherit theme;

  # Environment variables (shared + nvidia)
  inherit environmentVariables;

  # Services configuration (HP-specific NFS)
  inherit services;

  # Paths configuration (shared + HP external disk)
  inherit paths;
}
