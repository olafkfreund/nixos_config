{ pkgs, ... }: {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages32 = with pkgs.driversi686Linux; [
      # 32-bit Mesa DRI drivers for compatibility
      mesa
      # amdvlk removed - RADV (Mesa Vulkan) is now default
    ];
    extraPackages = with pkgs; [
      # Mesa DRI drivers for OpenGL/EGL support
      mesa
      # Vulkan and video acceleration
      vulkan-validation-layers
      libva-vdpau-driver
      # amdvlk removed - RADV (Mesa Vulkan) is now default
      rocmPackages.clr.icd
    ];
  };

  # Enable AMD GPU features
  hardware.amdgpu = {
    opencl.enable = true;
    # RADV (Mesa's Vulkan driver) is now enabled by default
    # amdvlk has been removed in favor of RADV
    # Load firmware early in the boot process for better stability
    # loadInInitrd = true;
  };

  environment = {
    systemPackages = with pkgs; [
      libva
      libva-utils
      # driversi686Linux.amdvlk removed - RADV is now default
      lact
      mesa-demos
      clinfo
      rocmPackages.rocm-smi
      rocmPackages.rocminfo
      rocmPackages.rocsolver # Temporarily disabled: depends on rocblas->hipblaslt (not in cache, build fails)
      rocmPackages.rocsparse
      rocmPackages.rocm-runtime
      rocmPackages.rpp-hip
      rocmPackages.rpp-cpu
      rocmPackages.clr
      rocmPackages.clr.icd
      rocmPackages.rocm-cmake
      rocmPackages.rocm-device-libs
      rocmPackages.hipblas # Temporarily disabled: depends on hipblaslt (not in cache, build fails)
      rocmPackages.rocblas # Temporarily disabled: depends on hipblaslt (not in cache, build fails)
      rocmPackages.hip-common
      radeontop
      # virtualglLib
      vulkan-loader
      vulkan-tools
      microcode-amd
    ];
  };

  # Systemd configuration
  systemd = {
    packages = with pkgs; [ lact ];
    services.lactd = {
      wantedBy = [ "multi-user.target" ];
      # Add restart-on-failure for better reliability
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    # Auto-apply high-performance GPU profile on boot
    services.lact-auto-profile = {
      description = "Apply LACT GPU high-performance profile";
      after = [ "lactd.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'sleep 5 && ${pkgs.lact}/bin/lact cli set-performance-level high || true'";
        RemainAfterExit = true;
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
    blacklistedKernelModules = [ "radeon" ];
  };

  # Environment variables for better AMD compatibility
  environment.variables = {
    # DRI and VA-API variables for proper driver loading
    LIBVA_DRIVER_NAME = "radeonsi";
    VDPAU_DRIVER = "radeonsi";
    DRI_PRIME = "1";

    # Uncomment if you want to force RADV (Mesa Vulkan driver)
    # AMD_VULKAN_ICD = "RADV";

    # ROCm environment variables for better compatibility
    # CRITICAL: Required for RX 7900 XTX (gfx1100) ROCm support
    HSA_OVERRIDE_GFX_VERSION = "11.0.0";
    # ROC_ENABLE_PRE_VEGA = "1";
  };
}
