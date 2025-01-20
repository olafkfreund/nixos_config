{
  config,
  pkgs,
  ...
}: {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      vulkan-validation-layers
      libva-vdpau-driver
      amdvlk
      rocmPackages.clr.icd
    ];
  };

  hardware.amdgpu.opencl.enable = true;
  hardware.amdgpu.amdvlk.enable = true;
  
  environment = {
    systemPackages = with pkgs; [
      libva
      libva-utils
      driversi686Linux.amdvlk
      lact
      glxinfo
      clinfo
      # virtualglLib
      # vulkan-loader
      # vulkan-tools
    ];
  };
  systemd = {
    packages = with pkgs; [lact];
    services.lactd.wantedBy = ["multi-user.target"];
  };
}
