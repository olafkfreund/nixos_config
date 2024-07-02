{ pkgs
, ...
}: {
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "mitigations=off" "module_blacklist=nouveau" ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.plymouth.enable = true;

  # This is for OBS Virtual Cam Support - v4l2loopback setup
  # boot.kernelPackages = pkgs.linuxPackages_default;
  # boot.kernelModules = ["v4l2loopback"];
  # boot.extraModulePackages = [config.boot.kernelPackages.v4l2loopback];
}
