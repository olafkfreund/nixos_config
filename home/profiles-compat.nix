# Profile System Compatibility Layer
# Provides backwards compatibility while enabling profile-based configurations
{ lib, pkgs, inputs, config, ... }:
let
  profilesLib = import ./profiles/default.nix { inherit lib; };

  # Extract profile name from configuration or use default
  profileName = config.meta.profile.name or "legacy";
  hostName = config.networking.hostName or "unknown";

  # Validate profile selection
  profileValid = profilesLib.validateProfile hostName profileName;

in
{
  imports = [
    # Import profile system
    ./profiles/default.nix
  ];

  # Profile-aware home configuration
  config = lib.mkMerge [
    # Base configuration (always applied)
    {
      home.packages = [
        inputs.self.packages.${pkgs.system}.claude-code
        inputs.self.packages.${pkgs.system}.opencode
        (pkgs.callPackage ../pkgs/weather-popup/default.nix { })
      ];

      # Profile metadata
      meta.profileSystem = {
        enabled = true;
        version = "1.0.0";
        availableProfiles = profilesLib.getHostProfiles hostName;
      };
    }

    # Legacy compatibility (when no profile is specified)
    (lib.mkIf (profileName == "legacy") {
      imports = [
        ./browsers/default.nix
        ./desktop/default.nix
        ./shell/default.nix
        ./development/default.nix
        ./media/music.nix
        ./media/spice_themes.nix
        ./files.nix
      ];

      # Legacy profile metadata
      meta.profile = {
        name = "legacy";
        type = "compatibility";
        description = "Legacy configuration compatibility mode";
      };
    })
  ];
}
