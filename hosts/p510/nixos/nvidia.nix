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
      # libvdpau-va-gl removed - old unmaintained package with CMake compatibility issues
      # nvidia-vaapi-driver and vaapiVdpau provide complete video acceleration for NVIDIA
    ];
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  # NVIDIA driver configuration for RTX 3070 Ti and RTX 3060
  hardware.nvidia = {
    # Modesetting is required for most Wayland compositors
    modesetting.enable = true;

    # Try open-source drivers for RTX 30 series (may work better with newer kernels)
    open = true;

    # Power management settings (disabled for server stability)
    powerManagement.enable = false;
    powerManagement.finegrained = false;

    # Nvidia settings GUI (disabled for headless server)
    nvidiaSettings = true;

    # Use beta driver for RTX 30 series with open-source drivers
    package = config.boot.kernelPackages.nvidiaPackages.beta;

    # Enable persistence daemon for headless operation
    nvidiaPersistenced = true;
  };

  # Kernel configuration for NVIDIA
  boot = {
    # Kernel parameters for proper NVIDIA functionality
    kernelParams = [
      "nvidia-drm.modeset=1" # Required for proper modesetting
    ];

    # Load NVIDIA kernel modules at boot (not in initrd)
    kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

    # Blacklist conflicting drivers
    blacklistedKernelModules = [ "nouveau" ];

    # Let hardware.nvidia module handle extraModulePackages automatically
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
