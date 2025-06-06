{
  pkgs,
  config,
  lib,
  ...
}: {
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages;
  boot.plymouth.enable = true;

  # Xeon E5-2698 v4 Optimizations
  boot.kernelParams = [
    "intel_pstate=active" # Enable Intel P-state driver for better power management
    "processor.max_cstate=1" # Limit C-states for better responsiveness
    "intel_idle.max_cstate=1" # Limit idle states for lower latency
    "pcie_aspm=off" # Disable PCIe Active State Power Management for workstation use
    "idle=nomwait" # Disable mwait for consistent performance
    "numa_balancing=disable" # Better for workstation loads with consistent memory access patterns
    "mitigations=auto" # Balance security mitigations with performance
  ];

  # Memory management for Xeon workstation
  boot.kernel.sysctl = {
    "vm.nr_hugepages" = 1024;
    "vm.max_map_count" = 1048576; # Helps with memory-mapped files for large models
    "vm.swappiness" = 10; # Reduce swap usage on workstation
    "vm.dirty_ratio" = 10; # Memory percentage for dirty pages before sync
    "vm.dirty_background_ratio" = 5; # Background dirty page sync percentage
    "kernel.numa_balancing" = 0; # Disable automatic NUMA balancing
  };

  # CPU Power Management
  boot.extraModprobeConfig = ''
    options intel_pstate no_hwp=1                # Disable hardware power management (better for workstation)
    # options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
  '';

  # Multi-core optimization
  boot.kernelModules = [
    # "v4l2loopback"
    "kvm-intel" # Optimized KVM for Intel CPUs
    "intel_rapl" # Intel power monitoring
  ];

  # Required kernel modules
  boot.initrd.kernelModules = [
    "e1000e" # Common Intel network driver
    "nvme" # For NVMe storage if present
    "xhci_pci" # USB 3.0 support
  ];

  # boot.extraModulePackages = with config.boot.kernelPackages; [
  #   v4l2loopback
  #   # intel-thermald # Thermal management for Intel CPUs
  # ];

  # Enable microcode updates
  hardware.cpu.intel.updateMicrocode = true;

  # For P510 ThinkStation hardware monitoring
  hardware.sensor.iio.enable = true;
}
