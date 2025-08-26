{ config
, pkgs
, ...
}: {
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    nvidiaPersistenced = false;  # Disabled due to rpc/rpc.h build error with latest drivers
    open = false;
    nvidiaSettings = true;
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

      # CUDA support
      # cudaPackages.cudatoolkit
      # cudaPackages.cudnn
    ];
  };
  environment = {
    systemPackages = with pkgs; [
      libva
      libva-utils
    ];
  };
}
