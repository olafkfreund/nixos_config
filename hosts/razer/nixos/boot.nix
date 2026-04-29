{ config, pkgs, ... }: {
  # Boot optimizations
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 10; # Keep 10 generations so known-good kernels stay selectable in the boot menu
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

  # Use systemd-based initrd. The legacy script-based initrd was timing out
  # waiting for /dev/disk/by-uuid/<root> to appear on kernel 7.0.1 — udev
  # ordering changes between 6.18 and 7.0 made the script-based wait fragile.
  # systemd-initrd listens on udev events directly instead of polling, and is
  # the recommended path for modern NVMe + NVIDIA setups.
  boot.initrd.systemd.enable = true;

  # Belt-and-braces: ensure NVMe-core is available in initrd. Linux 7.0
  # split some functionality from the main `nvme` module into `nvme_core`;
  # `nvme` (already from hardware-config) handles PCIe transport.
  boot.initrd.availableKernelModules = [ "nvme_core" ];

  # Kernel: trying linuxPackages_latest (7.0.1) on razer because 6.18.24 has a
  # boot regression with nvidia-open-595.58.03 + RTX 3080 Laptop (Ampere) — gen
  # 2443 was built with 6.18.24 + nvidia-open and failed to boot. 6.18.22 is
  # known-good (gen 2438, currently running). 6.17/6.19 are EOL'd in nixpkgs.
  # If 7.0.1 also fails to boot, fall back to pinning 6.18.22 via a separate
  # nixpkgs flake input. See: https://github.com/nixos/nixpkgs/issues/493618
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.plymouth.enable = true;
  boot.kernel.sysctl."vm.nr_hugepages" = 1024;
  # boot.kernel.sysctl = {
  #   "vm.max_map_count" = 1048576; # Helps with memory-mapped files for large models
  # };
  # OBS Virtual Cam Support - v4l2loopback setup
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=3 video_nr=1,2,10 card_label="OBS Virtual Cam 1","OBS Virtual Cam 2","COSMIC Camera" exclusive_caps=1,1,1
  '';

  # Blacklist nova_core to prevent conflicts with proprietary NVIDIA drivers (nixpkgs #473350)
  boot.blacklistedKernelModules = [ "nova_core" ];
}
