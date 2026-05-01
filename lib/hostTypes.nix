# Host Type Templates
# Provides standard import lists and configurations for different host types
# Eliminates duplicate import statements across host configurations
{ lib, ... }:
let
  desktopTemplate = profile: import ../hosts/templates/desktop.nix { inherit profile; };
in
{
  # Workstation configuration (P620, P510 - powerful desktop systems)
  workstation = {
    imports = [ (desktopTemplate "workstation") ];
    config = {
      aiDefaults.profile = "workstation";
      features = {
        development.enable = lib.mkDefault true;
        desktop.enable = lib.mkDefault true;
        virtualization.enable = lib.mkDefault true;
      };
    };
  };

  # Laptop configuration (Razer - portable system with power management)
  laptop = {
    imports = [ (desktopTemplate "laptop") ];
    config = {
      aiDefaults.profile = "laptop";
      features = {
        development.enable = lib.mkDefault true;
        desktop.enable = lib.mkDefault true;
        virtualization = {
          enable = lib.mkDefault true;
          docker = lib.mkDefault false;
        };
        powerManagement.enable = lib.mkDefault true;
      };
    };
  };
}
