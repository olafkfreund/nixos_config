{ pkgs, lib, ... }: {
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest; # Use the beta kernel for better hardware support
  boot.plymouth.enable = true;

  # Configure tmpfs size for large builds
  boot.tmp = {
    useTmpfs = true;
    tmpfsSize = "32G"; # Allocate 32GB of RAM for /tmp (increased for LibreOffice and large builds)
  };
  # This is for OBS Virtual Cam Support - v4l2loopback setup
  # boot.kernelPackages = pkgs.linuxPackages_default;
  # boot.kernelModules = ["v4l2loopback"];
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.blacklistedKernelModules = [ "nvidia" "nouveau" "v4l2loopback" ];
  boot.kernelParams = [
    "amdgpu.gpu_recovery=1"
    "amd_iommu=on"
    "processor.max_cstate=1" # Prevent deep sleep states for better responsiveness
    "rcu_nocbs=0-127" # Optimize RCU callbacks
    "numa_balancing=disable" # Can improve performance for some workloads
  ];
  # Force empty extraModulePackages to prevent any automatic inclusion
  boot.extraModulePackages = lib.mkForce [ ];
  systemd.tmpfiles.rules = [
    "f /dev/shm/scream 0660 olafkfreund qemu-libvirtd -"
    "f /dev/shm/looking-glass 0660 olafkfreund qemu-libvirtd -"
  ];
}
