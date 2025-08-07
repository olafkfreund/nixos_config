# Hardware configuration for workstation template
# 
# IMPORTANT: This is a template file. Replace with actual hardware configuration:
# nixos-generate-config --show-hardware-config > nixos/hardware-configuration.nix
#
# This template provides common hardware configurations as examples.

{ config, lib, modulesPath, ... }:

{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # CPU configuration - EXAMPLE (replace with your actual CPU)
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ]; # Change to "kvm-amd" for AMD CPUs
  boot.extraModulePackages = [ ];

  # File systems - EXAMPLE (replace with your actual configuration)
  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/REPLACE-WITH-YOUR-ROOT-UUID";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/REPLACE-WITH-YOUR-BOOT-UUID";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  # Swap configuration - EXAMPLE
  swapDevices =
    [{ device = "/dev/disk/by-uuid/REPLACE-WITH-YOUR-SWAP-UUID"; }];

  # Network interface - EXAMPLE (replace with your actual interface)
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp0s31f6.useDHCP = lib.mkDefault true;

  # Hardware acceleration and graphics
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # CPU-specific optimizations
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  # For AMD CPUs, use instead:
  # hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # GPU-specific configurations (uncomment based on your GPU)

  # For NVIDIA GPUs:
  # hardware.graphics.enable = true;
  # hardware.nvidia.modesetting.enable = true;
  # hardware.nvidia.powerManagement.enable = false;
  # hardware.nvidia.open = false;
  # hardware.nvidia.nvidiaSettings = true;

  # For AMD GPUs:
  # hardware.graphics.enable = true;
  # hardware.amdgpu.loadInInitrd = true;

  # For Intel integrated graphics:
  # hardware.graphics.enable = true;
  # hardware.graphics.extraPackages = with pkgs; [
  #   intel-media-driver
  #   intel-vaapi-driver
  #   libvdpau-va-gl
  # ];

  # Audio support
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Bluetooth support
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # Additional hardware support
  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = true;

  # USB and storage optimizations
  services.udev.extraRules = ''
    # USB device permissions
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", TAG+="uaccess"
    
    # Storage device optimizations
    ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
  '';

  # Power management
  powerManagement.enable = true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  # Kernel parameters for performance and compatibility
  boot.kernelParams = [
    "quiet"
    "splash"
    "mitigations=off" # Disable CPU vulnerability mitigations for performance (security trade-off)
    # Add more parameters based on your hardware
  ];

  # Firmware updates
  services.fwupd.enable = true;
}
