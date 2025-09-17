{ config
, pkgs
, ...
}: {
  # Graphics configuration (modern NixOS)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      # Vulkan support
      vulkan-validation-layers
      vulkan-loader
      vulkan-tools

      # Video acceleration - proper order matters
      vaapiVdpau
      libva-vdpau-driver
      nvidia-vaapi-driver
    ];
  };

  # NVIDIA driver configuration for RTX 3070 Ti and RTX 3060
  hardware.nvidia = {
    # Use open-source drivers for RTX 30-series (recommended)
    open = true;

    # Essential settings
    modesetting.enable = true;
    nvidiaSettings = false; # Disable GUI settings for headless operation

    # Power management (disabled for server stability)
    powerManagement.enable = false;
    powerManagement.finegrained = false;

    # Use stable driver version for reliability
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # Enable persistence daemon for headless operation
    nvidiaPersistenced = true;
  };

  # Kernel parameters for proper NVIDIA functionality
  boot = {
    kernelParams = [
      "nvidia-drm.modeset=1" # Required for proper modesetting
    ];

    # Blacklist conflicting drivers
    blacklistedKernelModules = [ "nouveau" ];
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
