{ pkgs
, config
, ...
}: {
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "systemd.unified_cgroup_hierarchy=0" "SYSTEMD_CGROUP_ENABLE_LEGACY_FORCE=1"];
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
