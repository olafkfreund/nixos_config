{ pkgs, lib, ... }: {
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # boot.kernelParams = [ "mitigations=off" "systemd.unified_cgroup_hierarchy=0" "SYSTEMD_CGROUP_ENABLE_LEGACY_FORCE=1"];
  boot.kernelParams = [ "mitigations=off" ];
  # boot.extraModprobeConfig = ''
  #    SYSTEMD_CGROUP_ENABLE_LEGACY_FORCE=1
  #    systemd.unified_cgroup_hierarchy=0
  # '';
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.plymouth.enable = true;

  # OBS Virtual Cam Support - v4l2loopback setup
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModulePackages = with pkgs.linuxPackages_latest; [ v4l2loopback ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=2 video_nr=1,2 card_label="OBS Virtual Cam 1","OBS Virtual Cam 2" exclusive_caps=1
  '';
}
