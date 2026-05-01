# Host Type Templates
# Provides standard import lists and configurations for different host types
# Eliminates duplicate import statements across host configurations
{ lib, ... }: {

  # Workstation configuration (P620, P510 - powerful desktop systems)
  workstation = {
    imports = [
      ../hosts/templates/workstation.nix
    ];

    # Workstation defaults
    config = {
      aiDefaults = {
        enable = lib.mkDefault true;
        profile = "workstation";
      };

      features = {
        development.enable = lib.mkDefault true;
        desktop.enable = lib.mkDefault true;
        virtualization.enable = lib.mkDefault true;
      };
    };
  };

  # Laptop configuration (Razer - portable system with power management)
  laptop = {
    imports = [
      ../hosts/templates/laptop.nix
    ];

    # Laptop-specific defaults
    config = {
      aiDefaults = {
        enable = lib.mkDefault true;
        profile = "laptop"; # Disables Ollama for battery life
      };

      features = {
        development.enable = lib.mkDefault true;
        desktop.enable = lib.mkDefault true;
        virtualization = {
          enable = lib.mkDefault true;
          docker = lib.mkDefault false; # Prefer Podman for battery life
        };
        powerManagement.enable = lib.mkDefault true;
      };

      # Laptop-specific power optimizations
      services.thermald.enable = lib.mkDefault true;
      powerManagement = {
        enable = lib.mkDefault true;
        cpuFreqGovernor = lib.mkDefault "powersave";
      };
    };
  };

}
