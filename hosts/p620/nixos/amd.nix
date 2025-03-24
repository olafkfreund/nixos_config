{
  config,
  pkgs,
  ...
}: {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages32 = with pkgs; [
      driversi686Linux.amdvlk
    ];
    extraPackages = with pkgs; [
      vulkan-validation-layers
      libva-vdpau-driver
      amdvlk
      rocmPackages.clr.icd
    ];
  };

  hardware.amdgpu.opencl.enable = true;
  hardware.amdgpu.amdvlk.supportExperimental.enable = true;
  hardware.amdgpu.amdvlk.enable = true;

  environment = {
    systemPackages = with pkgs; [
      libva
      libva-utils
      driversi686Linux.amdvlk
      lact
      glxinfo
      clinfo
      rocmPackages.rocm-smi
      rocmPackages.rocminfo
      rocmPackages.rocsolver
      rocmPackages.rocsparse
      rocmPackages.rocm-runtime
      rocmPackages.rpp-hip
      rocmPackages.rpp-cpu
      rocmPackages.clr
      rocmPackages.clr.icd
      rocmPackages.rocm-cmake
      rocmPackages.rocm-device-libs
      rocmPackages.hipblas
      rocmPackages.rocblas
      rocmPackages.hip-common
      radeontop
      # virtualglLib
      vulkan-loader
      vulkan-tools
    ];
  };

  systemd = {
    packages = with pkgs; [lact];
    services.lactd.wantedBy = ["multi-user.target"];
    tmpfiles.rules = [
      "L+    /opt/rocm   -    -    -     -    ${pkgs.rocmPackages.clr}"
    ];
  };
  # # Force radv
  # environment.variables.AMD_VULKAN_ICD = "RADV";
}
