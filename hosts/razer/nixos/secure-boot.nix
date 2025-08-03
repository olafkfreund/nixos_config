# Secure Boot configuration for Razer Blade
# Using Lanzaboote for NixOS Secure Boot support
{
  config,
  lib,
  pkgs,
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

  # Environment packages for managing Secure Boot
  environment.systemPackages = with pkgs; [
    sbctl # For managing Secure Boot keys
  ];
}