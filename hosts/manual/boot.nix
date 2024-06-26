{ self, config, pkgs, ... }: {

# Bootloader.
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = true;
boot.kernelParams = [ "module_blacklist=nouveau" ];
boot.kernelPackages = pkgs.linuxPackages_latest;
boot.plymouth.enable = true;
boot.plymouth.theme = "breeze";
}
