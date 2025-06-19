{
  pkgs,
  config,
  lib,
  ...
}: {
  # Boot optimizations
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5; # Limit number of configurations
    editor = false; # Disable bootloader editing for security
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # For Razer with i7-10875H
  boot.kernelParams = [
    "intel_pstate=active" # Use Intel P-state driver
    "intel_idle.max_cstate=2" # Limit C-states for better responsiveness when needed
    "i915.enable_fbc=1" # Enable framebuffer compression
    "i915.enable_guc=2" # Enable graphics microcontroller
    "nvme.noacpi=1" # Try if having NVMe issues
    "pcie_aspm=default" # PCIe Active State Power Management
  ];

  # For improved boot time
  boot.initrd.compressor = "zstd";
  boot.initrd.compressorArgs = ["-19" "-T0"];

  # Use latest kernel for newer hardware support
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.plymouth.enable = true;
  boot.kernel.sysctl."vm.nr_hugepages" = 1024;
  # boot.kernel.sysctl = {
  #   "vm.max_map_count" = 1048576; # Helps with memory-mapped files for large models
  # };
  # This is for OBS Virtual Cam Support - v4l2loopback setup
  # boot.kernelPackages = pkgs.linuxPackages_default;
  boot.kernelModules = ["v4l2loopback"];
  boot.extraModulePackages = with config.boot.kernelPackages; [
    v4l2loopback
  ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=2 video_nr=1,2 card_label="OBS Cam1","OBS Cam2" exclusive_caps=1
  '';
}
