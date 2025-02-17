{
  config,
  pkgs,
  ...
}: {
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    nvidiaPersistenced = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
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
      libva
      libva-utils
    ];
  };
}
