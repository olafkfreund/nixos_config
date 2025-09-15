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
      targetHosts = [ "dex5550" "p510" ];
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

    # Desktop user profile
    desktop-user = {
      description = "Full GUI configuration for desktop environments";
      targetHosts = [ "p620" ];
      inherits = [ ]; # Standalone profile
      features = {
        desktop = "full";
        gaming = true;
        development = "basic";
        multimedia = "full";
      };
    };

    # Laptop user profile
    laptop-user = {
      description = "Mobile-optimized configuration with power management";
      targetHosts = [ "razer" "samsung" ];
      inherits = [ ]; # Standalone profile
      features = {
        desktop = "mobile";
        gaming = "limited";
        development = "portable";
        multimedia = "efficient";
        powerManagement = true;
      };
    };
  };

  # Profile composition system - allows combining profiles
  compositions = {

    # Developer + Desktop User (P620 primary configuration)
    full-workstation = {
      description = "Full workstation combining development and desktop capabilities";
      combines = [ "developer" "desktop-user" ];
      targetHosts = [ "p620" ];
      overrides = {
        gaming.enable = true;
        development.languages = "all";
        desktop.quickshell = true; # P620-specific feature
      };
    };

    # Developer + Laptop User (Mobile development)
    mobile-developer = {
      description = "Mobile development setup with power optimization";
      combines = [ "developer" "laptop-user" ];
      targetHosts = [ "razer" ];
      overrides = {
        development.languages = "essential";
        editors.resource_intensive = false;
        powerManagement.aggressive = true;
      };
    };

    # Server Admin + Developer (Server with development tools)
    dev-server = {
      description = "Server with development capabilities for remote work";
      combines = [ "server-admin" "developer" ];
      targetHosts = [ "p510" ];
      overrides = {
        desktop.enable = false; # Force headless
        development.gui_tools = false;
        terminals.enable = false; # CLI only
      };
    };
  };

  # Profile resolution function
  resolveProfile = hostName: userName: profileName:
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
          description = profile.description;
          targetHosts = profile.targetHosts;
        };
      }
    else if composition != null then
    # Profile composition
      {
        imports = map (p: ./${p}/default.nix) composition.combines;
        meta.profile = {
          name = profileName;
          type = "composition";
          description = composition.description;
          combines = composition.combines;
          targetHosts = composition.targetHosts;
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
        (name: profile:
          builtins.elem hostName profile.targetHosts
        )
        profiles;

      compositionProfiles = lib.filterAttrs
        (name: composition:
          builtins.elem hostName composition.targetHosts
        )
        compositions;
    in
    singleProfiles // compositionProfiles;
in
{
  inherit profiles compositions resolveProfile validateProfile getHostProfiles;
}
