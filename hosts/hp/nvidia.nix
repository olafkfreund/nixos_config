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
  hardware.opengl = {
    enable = true;
    driSupport32Bit = true;
  };
  environment = {
    systemPackages = with pkgs; [
      libva
      libva-utils
    ];
  };
}
