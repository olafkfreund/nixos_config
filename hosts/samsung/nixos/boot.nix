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
  boot.blacklistedKernelModules = [ "v4l2loopback" ];

  # Force empty extraModulePackages to prevent any automatic inclusion  
  boot.extraModulePackages = lib.mkForce [ ];
}
