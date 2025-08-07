# AMD GPU configuration for workstation template
{ pkgs, lib, ... }:

{
  # AMD GPU hardware support
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      # AMD-specific packages
      amdvlk # AMD Vulkan driver
      rocmPackages.clr.icd # ROCm OpenCL driver

      # Video acceleration
      libva
      libva-vdpau-driver
      libvdpau-va-gl
      vaapiVdpau

      # Vulkan support
      vulkan-validation-layers
      vulkan-loader
      vulkan-tools

      # ROCm packages for AI/ML
      rocmPackages.rocm-runtime
      rocmPackages.rocminfo
      rocmPackages.rocm-smi
    ];

    extraPackages32 = with pkgs.driversi686Linux; [
      amdvlk
    ];
  };

  # Environment packages for AMD development and monitoring
  environment.systemPackages = with pkgs; [
    # AMD monitoring and control
    radeontop # AMD GPU monitoring
    rocmPackages.rocm-smi # ROCm system management
    rocmPackages.rocminfo # ROCm information

    # Development tools
    rocmPackages.llvm.libcxx
    rocmPackages.hip # HIP runtime
    rocmPackages.hipcc # HIP compiler

    # Vulkan utilities
    vulkan-tools
    vulkan-validation-layers

    # Video utilities
    libva-utils # VA-API utilities
    vdpauinfo # VDPAU information

    # Performance profiling
    rocmPackages.rocprofiler
    rocmPackages.roctracer
  ];

  # Environment variables for AMD ROCm
  environment.variables = {
    # ROCm configuration
    ROC_ENABLE_PRE_VEGA = "1";
    HCC_AMDGPU_TARGET = "gfx1100"; # Adjust based on your GPU
    HSA_OVERRIDE_GFX_VERSION = "11.0.0"; # Adjust based on your GPU

    # OpenCL configuration
    OPENCL_VENDOR_PATH = "${pkgs.rocmPackages.clr.icd}/etc/OpenCL/vendors";

    # Video acceleration
    LIBVA_DRIVER_NAME = "radeonsi";
    VDPAU_DRIVER = "radeonsi";

    # Mesa configuration
    MESA_LOADER_DRIVER_OVERRIDE = "radeonsi";
    AMD_VULKAN_ICD = "RADV";
  };

  # Session variables (for user sessions)
  environment.sessionVariables = {
    # Development paths
    ROCM_PATH = "${pkgs.rocmPackages.rocm-runtime}";
    HIP_PATH = "${pkgs.rocmPackages.hip}";

    # Library paths
    LD_LIBRARY_PATH = lib.mkAfter "${pkgs.rocmPackages.rocm-runtime}/lib:${pkgs.rocmPackages.hip}/lib";
  };

  # Kernel modules and parameters
  boot.kernelModules = [ "amdgpu" ];

  boot.kernelParams = [
    # AMD GPU specific parameters
    "amdgpu.si_support=1" # Southern Islands support
    "amdgpu.cik_support=1" # Sea Islands support
    "radeon.si_support=0" # Disable radeon for SI
    "radeon.cik_support=0" # Disable radeon for CIK

    # Performance and features
    "amdgpu.gpu_recovery=1" # Enable GPU recovery
    "amdgpu.ppfeaturemask=0xffffffff" # Enable all PowerPlay features

    # Memory management
    "amdgpu.vm_fragment_size=9" # Optimize VM fragments

    # Display configuration
    "amdgpu.dc=1" # Enable Display Core
    "amdgpu.dpm=1" # Enable Dynamic Power Management
  ];

  # Additional kernel configuration for gaming and performance
  boot.kernel.sysctl = {
    # Gaming optimizations
    "dev.i915.perf_stream_paranoid" = 0;
    "kernel.split_lock_mitigate" = 0;

    # Memory overcommit for large applications
    "vm.overcommit_memory" = 1;
    "vm.overcommit_ratio" = 100;
  };

  # Hardware-specific udev rules
  services.udev.extraRules = ''
    # AMD GPU rules
    KERNEL=="renderD*", GROUP="render", MODE="0664"
    KERNEL=="card*", GROUP="video", MODE="0664"

    # ROCm device permissions
    SUBSYSTEM=="drm", KERNEL=="renderD128", GROUP="render", MODE="0666"
    SUBSYSTEM=="kfd", KERNEL=="kfd", GROUP="render", MODE="0666"

    # Power management permissions
    KERNEL=="hwmon*", SUBSYSTEM=="hwmon", DRIVERS=="amdgpu", GROUP="users", MODE="0664"
  '';

  # Gaming and multimedia optimizations
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10;
        ioprio = 0;
        inhibit_screensaver = 1;
        softrealtime = "auto";
      };

      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
        amd_performance_level = "high";
      };
    };
  };

  # Audio configuration optimized for AMD
  services.pipewire = {
    extraConfig.pipewire = {
      "context.properties" = {
        # Optimize for AMD audio
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 1024;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 8192;
      };
    };
  };

  # Additional hardware support
  hardware = {
    # GPU scheduling
    graphics.driSupport = true;
    graphics.driSupport32Bit = true;

    # Audio support
    pulseaudio.support32Bit = true;

    # Bluetooth with A2DP support
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
      };
    };
  };

  # Power management specific to AMD
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "schedutil"; # Better for AMD Ryzen
  };

  # Security and performance tweaks
  security.pam.loginLimits = [
    {
      domain = "@users";
      item = "rtprio";
      type = "-";
      value = "1";
    }
    {
      domain = "@users";
      item = "nice";
      type = "-";
      value = "-11";
    }
    {
      domain = "@users";
      item = "memlock";
      type = "-";
      value = "unlimited";
    }
  ];

  # Systemd services for AMD optimization
  systemd.services.amd-pstate = {
    description = "AMD P-State Governor";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo schedutil > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'";
      RemainAfterExit = true;
    };
  };

  # Temperature and fan control (optional)
  # Uncomment if you have issues with fan curves
  # environment.systemPackages = with pkgs; [
  #   amdctl
  #   amdgpu-fan
  # ];

  # systemd.services.amdgpu-fan = {
  #   enable = false; # Set to true if needed
  #   description = "AMD GPU Fan Control";
  #   wantedBy = [ "multi-user.target" ];
  #   serviceConfig = {
  #     ExecStart = "${pkgs.amdgpu-fan}/bin/amdgpu-fan";
  #     Restart = "always";
  #     User = "root";
  #   };
  # };
}
