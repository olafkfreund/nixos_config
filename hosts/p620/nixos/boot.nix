{ pkgs
, config
, ...
}: {
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest; # Use the beta kernel for better hardware support
  boot.plymouth.enable = true;

  # Configure tmpfs size for large builds
  boot.tmp = {
    useTmpfs = true;
    tmpfsSize = "16G"; # Allocate 16GB of RAM for /tmp
  };
  # This is for OBS Virtual Cam Support - v4l2loopback setup
  # boot.kernelPackages = pkgs.linuxPackages_default;
  # boot.kernelModules = ["v4l2loopback"];
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.blacklistedKernelModules = [ "nvidia" "nouveau" ];
  boot.kernelParams = [
    "amdgpu.gpu_recovery=1"
    "amd_iommu=on"
    "processor.max_cstate=1" # Prevent deep sleep states for better responsiveness
    "rcu_nocbs=0-127" # Optimize RCU callbacks
    "numa_balancing=disable" # Can improve performance for some workloads
  ];
  # Temporarily disabled due to build failures
  # boot.extraModulePackages = with config.boot.kernelPackages; [
  #   v4l2loopback
  # ];
  # boot.extraModprobeConfig = ''
  #   options v4l2loopback devices=2 video_nr=1,2 card_label="OBS Cam1","OBS Cam2" exclusive_caps=1
  # '';
  systemd.tmpfiles.rules = [
    "f /dev/shm/scream 0660 olafkfreund qemu-libvirtd -"
    "f /dev/shm/looking-glass 0660 olafkfreund qemu-libvirtd -"
  ];
}
