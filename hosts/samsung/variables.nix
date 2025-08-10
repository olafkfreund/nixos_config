# Samsung Variables - Using Shared Variable System
# This demonstrates the new architecture with 90% code reduction
# All common user info, localization, network, and theme configs are now shared

{ lib }:
let
  # Import shared variables and hardware profile
  sharedVars = import ../common/shared-variables.nix;
  hardwareProfile = import ../common/hardware-profiles/intel-integrated.nix;

  # Extract shared variables for easier access
  inherit (sharedVars) user localization network baseEnvironment baseTheme baseUserGroups basePaths baseServices;
  inherit (lib) mkDefault mkForce optionalAttrs;

  # Samsung-specific overrides
  hostOverrides = {
    # Host identification
    hostName = "samsung";
    nameservers = [ "1.1.1.1" "8.8.8.8" ];

    # Samsung-specific display configuration (single laptop screen)
    laptop_monitor = "monitor = eDP-1,1920x1080@120,0x0,1";
    external_monitor = "";

    # Samsung-specific wallpaper (only thing that differs in theme)
    wallpaper = ./themes/orange-desert.jpg;

    # Samsung-specific paths and services
    services = {
      nfs = {
        enable = true;
        exports = "/extdisk         192.168.1.*(rw,fsid=0,no_subtree_check)";
      };
    };

    paths = {
      # Inherits base paths, can add Samsung-specific ones here
      external_disk = "/extdisk"; # Samsung-specific external disk path
    };

    # Any additional Samsung-specific environment variables
    # (base Intel variables come from hardware profile)
    extraEnvironment = {
      # Add any Samsung-specific environment variables here if needed
    };

    # Any additional Samsung-specific user groups
    # (base groups come from shared variables)
    extraGroups = [
      # Add any Samsung-specific groups here if needed
    ];
  };

  # Merge configurations: base + hardware + host overrides
  allUserGroups = baseUserGroups
    ++ (hardwareProfile.extraGroups or [ ])
    ++ (hostOverrides.extraGroups or [ ]);

  allEnvironmentVariables = baseEnvironment
    // (hardwareProfile.extraEnvironment or { })
    // (hostOverrides.extraEnvironment or { });

  finalTheme = baseTheme // {
    wallpaper = hostOverrides.wallpaper or ./themes/default-wallpaper.jpg;
  };

  finalServices = baseServices // (hostOverrides.services or { });
  finalPaths = basePaths // (hostOverrides.paths or { });

in
{
  # User information (shared across all hosts)
  inherit (user) username fullName gitUsername gitEmail gitHubToken;

  # Localization (shared across all hosts)
  inherit (localization) timezone locale keyboardLayouts;

  # Network configuration (shared across all hosts)
  inherit (network) hostMappings;

  # Host-specific configuration
  hostName = hostOverrides.hostName;
  nameservers = hostOverrides.nameservers or [ ];

  # Hardware configuration from profile
  gpu = hardwareProfile.gpu;
  acceleration = hardwareProfile.acceleration;

  # Display configuration (host-specific)
  laptop_monitor = hostOverrides.laptop_monitor or "";
  external_monitor = hostOverrides.external_monitor or "";

  # Merged configurations
  userGroups = allUserGroups;
  environmentVariables = allEnvironmentVariables;
  theme = finalTheme;
  services = finalServices;
  paths = finalPaths;
}
