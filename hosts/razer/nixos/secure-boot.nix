# Secure Boot configuration for Razer Blade
# Using Lanzaboote for NixOS Secure Boot support
{
  config,
  lib,
  ...
}: {
  # Import lanzaboote module
  imports = [
    # Lanzaboote module will be imported from flake
  ];

  # Enable Lanzaboote for Secure Boot
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/etc/secureboot";
  };

  # Disable systemd-boot when using lanzaboote
  boot.loader.systemd-boot.enable = lib.mkForce false;

  # Still need EFI variables
  boot.loader.efi.canTouchEfiVariables = true;

  # Secure Boot packages moved to main configuration.nix for conditional inclusion
}