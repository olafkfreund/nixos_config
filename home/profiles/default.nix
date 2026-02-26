# Home Manager Profiles System
# Provides profile-based user configurations with inheritance and composition
{ lib, ... }:
with lib;
let
  # Profile definitions with inheritance capabilities
  profiles = {

    # Base server administration profile
    server-admin = {
      description = "Minimal headless configuration for server administration";
      targetHosts = [ "p510" ];
      features = {
        desktop = false;
        gaming = false;
        development = "minimal";
        multimedia = false;
      };
    };

    # Development-focused profile
    developer = {
      description = "Development-focused configuration with full toolchain";
      targetHosts = [ "p620" "p510" "razer" ];
      inherits = [ ]; # Standalone profile
      features = {
        desktop = "optional";
        gaming = false;
        development = "full";
        multimedia = "basic";
      };
    };

  };

  # Profile compositions removed - hosts import profiles directly
  compositions = { };

  # Profile resolution function
  resolveProfile = _hostName: _userName: profileName:
    let
      profile = profiles.${profileName} or null;
      composition = compositions.${profileName} or null;
    in
    if profile != null then
    # Single profile
      {
        imports = [ ./${profileName}/default.nix ];
        meta.profile = {
          name = profileName;
          type = "single";
          inherit (profile) description;
          inherit (profile) targetHosts;
        };
      }
    else if composition != null then
    # Profile composition
      {
        imports = map (p: ./${p}/default.nix) composition.combines;
        meta.profile = {
          name = profileName;
          type = "composition";
          inherit (composition) description;
          inherit (composition) combines;
          inherit (composition) targetHosts;
          overrides = composition.overrides or { };
        };
      }
    else
    # Fallback to legacy configuration
      {
        imports = [ ../default.nix ];
        meta.profile = {
          name = "legacy";
          type = "fallback";
          description = "Legacy configuration fallback";
        };
      };

  # Profile validation function
  validateProfile = hostName: profileName:
    let
      profile = profiles.${profileName} or null;
      composition = compositions.${profileName} or null;
      target = if profile != null then profile else composition;
    in
    if target == null then
      lib.warn "Profile '${profileName}' not found for host '${hostName}', using fallback"
    else if !(builtins.elem hostName target.targetHosts) then
      lib.warn "Profile '${profileName}' not recommended for host '${hostName}'"
    else
      true;

  # Helper function to get available profiles for a host
  getHostProfiles = hostName:
    let
      singleProfiles = lib.filterAttrs
        (_name: profile:
          builtins.elem hostName profile.targetHosts
        )
        profiles;

      compositionProfiles = lib.filterAttrs
        (_name: composition:
          builtins.elem hostName composition.targetHosts
        )
        compositions;
    in
    singleProfiles // compositionProfiles;
in
{
  inherit profiles compositions resolveProfile validateProfile getHostProfiles;
}
