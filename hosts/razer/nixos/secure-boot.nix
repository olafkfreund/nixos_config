# Secure Boot configuration for Razer Blade
# Using Lanzaboote for NixOS Secure Boot support
{ lib, ... }: {
  # Import lanzaboote module
  imports = [
    # Lanzaboote module will be imported from flake
  ];

  # Boot configuration for Secure Boot
  boot = {
    # Enable Lanzaboote for Secure Boot
    lanzaboote = {
      enable = true;
      pkiBundle = "/etc/secureboot";
    };

    # Bootloader configuration
    loader = {
      # Disable systemd-boot when using lanzaboote
      systemd-boot.enable = lib.mkForce false;
      # Still need EFI variables
      efi.canTouchEfiVariables = true;
    };
  };

  # Secure Boot packages moved to main configuration.nix for conditional inclusion
}
