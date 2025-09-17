{ config
, pkgs
, ...
}: {
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    nvidiaPersistenced = true; # Enable for headless operation (keeping device nodes persistent)
    open = false;
    nvidiaSettings = false; # Disable GUI settings for headless
    package = config.boot.kernelPackages.nvidiaPackages.production; # Use production drivers for stability
  };
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      # Vulkan support
      vulkan-validation-layers
      vulkan-loader
      vulkan-tools

      # Video acceleration
      libva-vdpau-driver
      nvidia-vaapi-driver
      vaapiVdpau
    ];
  };
  environment = {
    systemPackages = with pkgs; [
      libva
      libva-utils
      # CUDA tools for development and debugging
      cudaPackages.cuda_nvcc
      cudaPackages.cudatoolkit
      cudaPackages.cudnn
    ];
  };
}
