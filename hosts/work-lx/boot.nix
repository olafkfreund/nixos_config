{ self, config, pkgs, ... }: {

# Bootloader.
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = true;
boot.kernelParams = [ 
  "module_blacklist=nouveau"
  "i915.modeset=1"
  "i915.enable_fbc=0"
  "i915.enable_psr=0"
];
boot.kernelPackages = pkgs.linuxPackages_latest;
}
