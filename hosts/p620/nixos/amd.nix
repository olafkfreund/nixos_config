{
  config,
  pkgs,
  ...
}: {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages32 = with pkgs.driversi686Linux; [
      amdvlk
    ];
    extraPackages = with pkgs; [
      vulkan-validation-layers
      libva-vdpau-driver
      amdvlk
      rocmPackages.clr.icd
    ];
  };

  # Enable AMD GPU features
  hardware.amdgpu = {
    opencl.enable = true;
    amdvlk = {
      enable = true;
      supportExperimental.enable = true;
    };
    # Load firmware early in the boot process for better stability
    # loadInInitrd = true;
  };

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

  # Systemd configuration
  systemd = {
    packages = with pkgs; [lact];
    services.lactd = {
      wantedBy = ["multi-user.target"];
      # Add restart-on-failure for better reliability
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
    tmpfiles.rules = [
      "L+    /opt/rocm   -    -    -     -    ${pkgs.rocmPackages.clr}"
    ];
  };

  # Performance tuning
  boot = {
    # Kernel parameters for better GPU performance
    kernelParams = [
      "amdgpu.ppfeaturemask=0xffffffff" # Enable power management features
      "amdgpu.dcfeaturemask=1" # Enable display core features
    ];
    # Blacklist incompatible modules
    blacklistedKernelModules = ["radeon"];
  };

  # Environment variables for better AMD compatibility
  environment.variables = {
    # Uncomment if you want to force RADV (Mesa Vulkan driver)
    AMD_VULKAN_ICD = "RADV";

    # ROCm environment variables for better compatibility
    # HSA_OVERRIDE_GFX_VERSION = "10.3.0";
    # ROC_ENABLE_PRE_VEGA = "1";
  };
}
