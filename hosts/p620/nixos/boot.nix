{ pkgs, ... }: {
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10; # Limit boot entries to prevent /boot from filling up
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest; # Use the beta kernel for better hardware support
  boot.plymouth.enable = true;

  # Configure tmpfs size for large builds
  boot.tmp = {
    useTmpfs = true;
    tmpfsSize = "32G"; # Allocate 32GB of RAM for /tmp (increased for LibreOffice and large builds)
  };
  # OBS Virtual Cam Support - v4l2loopback setup
  boot.kernelModules = [ "v4l2loopback" ];
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.blacklistedKernelModules = [ "nvidia" "nouveau" ];
  boot.kernelParams = [
    "amdgpu.gpu_recovery=1"
    "amd_iommu=on"
    "processor.max_cstate=1" # Prevent deep sleep states for better responsiveness
    "rcu_nocbs=0-127" # Optimize RCU callbacks
    "numa_balancing=disable" # Can improve performance for some workloads
  ];
  # v4l2loopback for OBS Virtual Camera support
  boot.extraModulePackages = with pkgs.linuxPackages_latest; [ v4l2loopback ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=3 video_nr=1,2,10 card_label="OBS Virtual Cam 1","OBS Virtual Cam 2","COSMIC Camera" exclusive_caps=1,1,1
  '';
  systemd.tmpfiles.rules = [
    "f /dev/shm/scream 0660 olafkfreund qemu-libvirtd -"
    "f /dev/shm/looking-glass 0660 olafkfreund qemu-libvirtd -"
  ];
}
