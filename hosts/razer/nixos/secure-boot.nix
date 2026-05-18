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

  # razer's fTPM returns TPM_RC_NV_UNAVAILABLE (0x921) when systemd 256+
  # tries to seal an "anchor secret" to NV during boot. Nothing on this host
  # consumes the seal (no LUKS-TPM2, no systemd-cryptenroll, no PCR unsealing
  # — kernel cmdline has no cryptdevice/rd.luks.*, no /etc/crypttab, no tpm2
  # references in host config). Without suppression, the unit fails on every
  # boot and `nh os switch` exits 4 even though activation actually succeeded.
  # The early variant (initrd, sets up SRK) is unaffected and still runs.
  systemd.suppressedSystemUnits = [ "systemd-tpm2-setup.service" ];
}
