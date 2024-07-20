{ pkgs
, config
, ...
}: {
  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;
  boot.kernelParams = [ "mitigations=off" ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.plymouth.enable = true;

  # This is for OBS Virtual Cam Support - v4l2loopback setup
  # boot.kernelPackages = pkgs.linuxPackages_default;
  boot.kernelModules = ["v4l2loopback"];
  boot.extraModulePackages = with config.boot.kernelPackages; [
    v4l2loopback
  ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
  '';
}
