# Simplified Performance Profiles
{ ... }:
let
  profiles = {
    balanced = {
      animations = { enabled = true; };
      graphics = {
        blur = { enabled = true; };
        shadows = { enabled = false; };
        vrr = true;
        allow_tearing = false;
      };
    };
  };
in
{
  hyprland.performanceProfiles = profiles;
  hyprland.getProfile = profileName: profiles.${profileName} or profiles.balanced;
}
