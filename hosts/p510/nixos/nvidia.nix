{ config
, pkgs
, ...
}: {
  # Graphics configuration (modern NixOS 24.11+)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      # Vulkan support
      vulkan-validation-layers
      vulkan-loader
      vulkan-tools

      # Video acceleration
      nvidia-vaapi-driver
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  # NVIDIA driver configuration for RTX 3070 Ti and RTX 3060
  hardware.nvidia = {
    # Modesetting is required for most Wayland compositors
    modesetting.enable = true;

    # Use open-source kernel modules for RTX 30 series (Ampere)
    # RTX 3060 and 3070 Ti are Ampere architecture, recommended to use open drivers
    open = true;

    # Power management settings (disabled for server stability)
    powerManagement.enable = false;
    powerManagement.finegrained = false;

    # Nvidia settings GUI (disabled for headless server)
    nvidiaSettings = false;

    # Use stable driver version with latest stable kernel
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # Enable persistence daemon for headless operation
    nvidiaPersistenced = true;
  };

  # Kernel configuration for NVIDIA
  boot = {
    # Kernel parameters for proper NVIDIA functionality
    kernelParams = [
      "nvidia-drm.modeset=1" # Required for proper modesetting
    ];

    # These modules are automatically loaded by the nvidia module
    # No need to explicitly specify them
    # kernelModules = [ ];

    # Blacklist conflicting drivers
    blacklistedKernelModules = [ "nouveau" ];

    # Ensure NVIDIA modules are in extraModulePackages
    extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];
  };

  # Docker NVIDIA support
  hardware.nvidia-container-toolkit.enable = true;

  # Create proper device nodes for NVIDIA
  services.udev.extraRules = ''
    KERNEL=="nvidia_uvm", GROUP="video", MODE="0664"
    KERNEL=="nvidia*", GROUP="video", MODE="0664"
  '';

  environment.systemPackages = with pkgs; [
    # NVIDIA monitoring
    nvtopPackages.nvidia # NVIDIA system monitor
    libva
    libva-utils

    # CUDA tools for development and debugging
    cudaPackages.cuda_nvcc
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
  ];
}
