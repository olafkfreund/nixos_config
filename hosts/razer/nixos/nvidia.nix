{
  config,
  pkgs,
  ...
}: {
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    nvidiaPersistenced = true;
    open = false; # Use proprietary drivers for better Wayland compatibility
    nvidiaSettings = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable; # Use stable instead of beta
  };

  hardware.nvidia.prime = {
    sync.enable = true;
    offload.enable = false;
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };

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

      # # CUDA support
      # cudaPackages.cudatoolkit
      # cudaPackages.cudnn
    ];
  };

  environment = {
    systemPackages = with pkgs; [
      # nvidia-vaapi-driver
      libva
      libva-utils
      # nvtop
      # glxinfo
      # clinfo
      # virtualglLib
      # vulkan-loader
      # vulkan-tools
    ];
  };
  # Kernel parameters for better NVIDIA performance and stability
  boot = {
    kernelParams = [
      "nvidia-drm.modeset=1" # Required for Wayland
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1" # Helps with suspend/resume
    ];

    # Early load NVIDIA modules
    initrd.kernelModules = ["nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"];
  };

  # Remove global Firefox/Chromium configs to avoid conflicts
  # These will be handled in individual user configurations

  # Docker NVIDIA support
  hardware.nvidia-container-toolkit.enable = true;
}
