{ }:
let
  # Import shared variables and Intel hardware profile
  sharedVars = import ../common/shared-variables.nix;
  hardwareProfile = import ../common/hardware-profiles/intel-integrated.nix;

  # DEX5550-specific overrides (monitoring server)
  hostOverrides = {
    hostName = "dex5550";
    nameservers = [ "1.1.1.1" "8.8.8.8" ]; # External DNS for monitoring server

    # Server-specific user groups (no GUI-related groups)
    serverUserGroups = [
      "networkmanager"
      "libvirtd"
      "wheel"
      "docker"
      "podman"
      "lxd"
      "incus-admin"
    ];

    # Server environment (minimal for headless)
    serverEnvironment = {
      NIXPKGS_ALLOW_INSECURE = "1";
      NIXPKGS_ALLOW_UNFREE = "1";
    };

    # NFS disabled for monitoring server
    nfsConfig = {
      enable = false;
      exports = "";
    };

    # Keyboard layout for console only (headless)
    keyboardLayouts = {
      console = "uk"; # For virtual console only
    };
  };

  # Merge shared variables with hardware profile and server overrides
  user = sharedVars.user // { };
  localization = sharedVars.localization // {
    inherit (hostOverrides) keyboardLayouts; # Server override
  };

  # Merge network configuration
  network = sharedVars.network // {
    inherit (hostOverrides) hostName nameservers;
  };

  # Hardware configuration from Intel profile
  hardware = {
    inherit (hardwareProfile) gpu acceleration videoDrivers extraEnvironment;
  };

  # No theme needed for headless server
  theme = { };

  # Environment variables: minimal server environment only
  environmentVariables = hostOverrides.serverEnvironment;

  # User groups: server-specific groups (no GUI groups)
  userGroups = hostOverrides.serverUserGroups;

  # Services configuration
  services = {
    nfs = hostOverrides.nfsConfig;
  };

  # Paths configuration (shared)
  paths = sharedVars.basePaths;

in
{
  # User information (shared across all hosts)
  inherit (user) username fullName gitUsername gitEmail gitHubToken;

  # Hardware configuration (Intel integrated graphics)
  inherit (hardware) gpu acceleration;

  # User groups (server-optimized)
  inherit userGroups;

  # Network configuration (shared base + server overrides)
  inherit (network) hostName nameservers;
  inherit (network) hostMappings;

  # Localization (shared + server keyboard layout)
  inherit (localization) timezone locale keyboardLayouts;

  # Theme configuration (empty for headless server)
  inherit theme;

  # Environment variables (minimal server environment)
  inherit environmentVariables;

  # Services configuration (NFS disabled)
  inherit services;

  # Paths configuration (shared)
  inherit paths;
}
