# Laptop Template - Mobile Configuration with Power Management
# Used by: Razer (Intel/NVIDIA laptop), Samsung, portable systems
{ lib, ... }:
{
  imports = [
    ../../modules/core.nix
    ../../modules/development.nix
    ../../modules/desktop.nix
    ../../modules/virtualization.nix
    ../../modules/performance.nix
    ../../modules/email.nix
    ../../modules/cloud.nix
    ../../modules/programs.nix
    ../../modules/common/ai-defaults.nix
    ../../modules/windows/winboat.nix
  ];

  # Laptop-specific defaults
  config = {
    aiDefaults = {
      enable = lib.mkDefault true;
      profile = "laptop"; # Disables Ollama for battery life
    };

    # Laptop-specific power optimizations
    services = {
      thermald.enable = lib.mkDefault true;
      openssh.enable = lib.mkDefault true;
    };

    powerManagement = {
      enable = lib.mkDefault true;
      cpuFreqGovernor = lib.mkDefault "powersave";
    };
  };
}
