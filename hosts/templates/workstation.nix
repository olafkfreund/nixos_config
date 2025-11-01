# Workstation Template - Full Desktop Configuration
# Used by: P620 (AMD workstation), powerful desktop systems
{ config, lib, pkgs, ... }:
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

  # Workstation defaults
  config = {
    aiDefaults = {
      enable = lib.mkDefault true;
      profile = "workstation";
    };

    # Workstation optimizations
    services.openssh.enable = lib.mkDefault true;
  };
}
