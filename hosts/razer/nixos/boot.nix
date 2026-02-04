{ pkgs, ... }: {
  # Boot optimizations
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 3; # Keep at least 3 generations for easy rollback
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
    "button.lid_init_state=open" # Lid open state on boot
    "mitigations=off" # Disable all CPU mitigations for performance (use with caution)
  ];

  # For improved boot time
  boot.initrd.compressor = "zstd";
  boot.initrd.compressorArgs = [ "-19" "-T0" ];

  # Use kernel 6.18 for NVIDIA driver compatibility and newer hardware support
  boot.kernelPackages = pkgs.linuxPackages_6_18;

  boot.plymouth.enable = true;
  boot.kernel.sysctl."vm.nr_hugepages" = 1024;
  # boot.kernel.sysctl = {
  #   "vm.max_map_count" = 1048576; # Helps with memory-mapped files for large models
  # };
  # OBS Virtual Cam Support - v4l2loopback setup
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModulePackages = with pkgs.linuxPackages_6_18; [ v4l2loopback ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=3 video_nr=1,2,10 card_label="OBS Virtual Cam 1","OBS Virtual Cam 2","COSMIC Camera" exclusive_caps=1,1,1
  '';
}
