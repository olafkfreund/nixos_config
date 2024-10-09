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
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  environment = {
    systemPackages = with pkgs; [
      libva
      libva-utils
    ];
  };
}
