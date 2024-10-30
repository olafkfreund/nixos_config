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
    open = true;
    nvidiaSettings = false;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
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
      vulkan-validation-layers
      libva-vdpau-driver
      nvidia-vaapi-driver
    ];
  };

  environment = {
    systemPackages = with pkgs; [
      nvidia-vaapi-driver
      libva
      libva-utils
      glxinfo
      clinfo
      virtualglLib
      vulkan-loader
      vulkan-tools
    ];
  };
}
