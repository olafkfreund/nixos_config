# Secure Boot configuration for Razer Blade
# Using Lanzaboote for NixOS Secure Boot support
{ lib, ... }: {
  # Boot configuration for Secure Boot
  boot = {
    # Enable bootspec for lanzaboote (required for Secure Boot)
    bootspec.enable = true;

    # Enable Lanzaboote for Secure Boot.
    # pkiBundle path changed from /etc/secureboot to /var/lib/sbctl in
    # sbctl 0.14+ (lanzaboote v1.0.0 ships sbctl 0.18). Keys live at
    # /var/lib/sbctl/keys/{db,KEK,PK}/*.{key,pem}.
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
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
