{ config
, pkgs
, ...
}: {
  hardware = {
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false; # Keep disabled for server stability
      nvidiaPersistenced = true; # Enable for headless operation (keeping device nodes persistent)
      open = false;
      nvidiaSettings = false; # Disable GUI settings for headless
      package = config.boot.kernelPackages.nvidiaPackages.production; # Use production drivers for stability
    };

    graphics = {
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

    # Docker NVIDIA support
    nvidia-container-toolkit.enable = true;
  };

  # Kernel parameters for proper NVIDIA functionality
  boot = {
    kernelParams = [
      "nvidia-drm.modeset=1" # Required for proper modesetting
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1" # Helps with suspend/resume
      "nvidia.NVreg_TemporaryFilePath=/tmp" # Fix for temp file issues
    ];

    # Load NVIDIA modules at boot time (not in initrd)
    kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  };

  # Create proper device nodes for NVIDIA
  services.udev.extraRules = ''
    KERNEL=="nvidia_uvm", GROUP="video", MODE="0664"
    KERNEL=="nvidia*", GROUP="video", MODE="0664"
  '';

  environment = {
    systemPackages = with pkgs; [
      libva
      libva-utils
      nvtopPackages.nvidia # NVIDIA system monitor
      # CUDA tools for development and debugging
      cudaPackages.cuda_nvcc
      cudaPackages.cudatoolkit
      cudaPackages.cudnn
    ];
  };
}
