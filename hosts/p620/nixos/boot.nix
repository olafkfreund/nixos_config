{
  pkgs,
  config,
  ...
}: {
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.plymouth.enable = true;
  boot.kernel.sysctl."vm.nr_hugepages" = 1024;
  # This is for OBS Virtual Cam Support - v4l2loopback setup
  # boot.kernelPackages = pkgs.linuxPackages_default;
  boot.kernelModules = ["v4l2loopback"];
  boot.initrd.kernelModules = ["amdgpu"];
  boot.blacklistedKernelModules = ["nvidia" "nouveau"];
  boot.kernelParams = ["amdgpu.gpu_recovery=1" "amd_iommu=on" "vfio_virqfd" "vfio_pci" "vfio_iommu_type1" "vfio"];
  boot.extraModulePackages = with config.boot.kernelPackages; [
    v4l2loopback
  ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=2 video_nr=1,2 card_label="OBS Cam1","OBS Cam2" exclusive_caps=1
  '';
  postBootCommands = ''
    DEVS="0000:c1:00.0 0000:c1:00.1"

    for DEV in $DEVS; do
      echo "vfio-pci" > /sys/bus/pci/devices/$DEV/driver_override
    done
    modprobe -i vfio-pci
  '';
}
