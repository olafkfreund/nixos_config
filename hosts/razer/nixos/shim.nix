{ config, lib, pkgs, ... }:
# Shim integration for razer.
#
# Razer's firmware has the Razer "Platform Key" set as PK and won't expose a
# "Reset Secure Boot keys" / "Setup Mode" option in BIOS — we cannot enroll
# our own db key directly via sbctl enroll-keys. (Confirmed across multiple
# 2021+ Razer Blade models; see issue #376 for the research.)
#
# Workaround: chain through Ubuntu's Microsoft-dualsigned shim. Razer's `db`
# already trusts the "Microsoft Corporation UEFI CA 2011" (verified via
# /sys/firmware/efi/efivars/db-*), which signs Ubuntu's shim. shim ships a
# UEFI app called MokManager (mmx64.efi) that lets us enroll our own key as
# a Machine Owner Key WITHOUT touching Setup Mode.
#
# Architecture after install:
#   firmware → /EFI/BOOT/BOOTX64.EFI (= shim, Microsoft-signed)
#            → /EFI/BOOT/grubx64.efi (= lanzaboote-stub, signed by our db key,
#              trusted via the MOK we enroll once via mokutil + reboot)
#            → /EFI/Linux/nixos-generation-N.efi (UKI, signed by our db key)
#            → kernel + initrd
#
# Reference: working setup posted by user "Mareo" on
# https://github.com/nix-community/lanzaboote/issues/165
let
  # Ubuntu's shim-signed package — ships shim signed by both Microsoft (via the
  # 3rd Party UEFI CA — what our firmware trusts) and Canonical, plus mmx64.efi
  # (MokManager).
  #
  # Pin to a specific .deb on launchpad: launchpad URLs are immutable per file,
  # so this hash is stable forever. Bump only after verifying a newer version
  # also boots on this hardware.
  shimUbuntu = pkgs.stdenvNoCC.mkDerivation {
    pname = "shim-ubuntu-signed";
    version = "1.59+15.8-0ubuntu2";

    src = pkgs.fetchurl {
      url = "https://launchpad.net/ubuntu/+archive/primary/+files/shim-signed_1.59+15.8-0ubuntu2_amd64.deb";
      hash = "sha256-+O1xzi2RowS21euEmX+EbzMbVUV4vALb/njhOtisgak=";
    };

    nativeBuildInputs = [ pkgs.dpkg ];

    unpackPhase = "dpkg-deb -x $src .";

    installPhase = ''
      mkdir -p $out
      # Use the dualsigned variant — has both Microsoft and Canonical sigs
      # for maximum firmware compatibility. Singletons are also available
      # at shimx64.efi.signed.latest if dualsigned ever gets dropped.
      cp usr/lib/shim/shimx64.efi.dualsigned $out/shimx64.efi
      cp usr/lib/shim/mmx64.efi              $out/mmx64.efi
    '';

    meta = {
      description = "Ubuntu's Microsoft+Canonical dualsigned shim and MokManager UEFI binaries";
      homepage = "https://launchpad.net/ubuntu/+source/shim-signed";
      license = lib.licenses.bsd2;
      platforms = [ "x86_64-linux" ];
    };
  };
in
{
  config = lib.mkIf config.boot.lanzaboote.enable {
    # Wrap lanzaboote's bootloader installer so every nixos-rebuild boot/switch
    # also stages shim. We override system.build.installBootLoader rather than
    # using activation scripts because activation only runs on `switch`, not
    # on `boot` — and we need shim staged on /boot before any reboot.
    #
    # Reads boot.lanzaboote.installCommand (the partial lzbt invocation) and
    # invokes it with our $@ args, then performs the shim staging atomically.
    system.build.installBootLoader = lib.mkForce (pkgs.writeShellScript "install-bootloader-with-shim" ''
      set -euo pipefail

      # Step 1: lanzaboote's standard install. Writes signed BOOTX64.EFI
      # (= lanzaboote-stub) and per-generation UKIs in /EFI/Linux/.
      ${config.boot.lanzaboote.installCommand} "$@"

      # Step 2: shim swap. Move lanzaboote-stub aside as grubx64.efi (the
      # hardcoded name shim chainloads by default — even though we're chain-
      # loading lanzaboote, not grub, the historical name sticks). Then
      # overwrite BOOTX64.EFI with Microsoft-signed shim.
      cp -f /boot/EFI/BOOT/BOOTX64.EFI /boot/EFI/BOOT/grubx64.efi
      install -m 0755 ${shimUbuntu}/shimx64.efi /boot/EFI/BOOT/BOOTX64.EFI

      # MokManager — required to enroll our MOK at first SB-enabled boot.
      install -m 0755 ${shimUbuntu}/mmx64.efi /boot/EFI/BOOT/mmx64.efi

      echo "shim-install: BOOTX64.EFI=shim (Ubuntu dualsigned 1.59+15.8); grubx64.efi=lanzaboote-stub"
    '');

    # Also add mokutil to system PATH so user can `mokutil --import` etc.
    # without a nix shell.
    environment.systemPackages = [ pkgs.mokutil ];
  };
}
