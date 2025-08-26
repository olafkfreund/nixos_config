# Intel GPU configuration for workstation template
{ config
, pkgs
, lib
, ...
}: {
  # Intel graphics hardware support
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      # Intel-specific packages
      intel-media-driver # Modern Intel GPUs (Broadwell+)
      intel-vaapi-driver # Legacy Intel GPUs
      libvdpau-va-gl # VDPAU over VA-API
      intel-compute-runtime # OpenCL runtime

      # Vulkan support
      vulkan-validation-layers
      vulkan-loader
      vulkan-tools

      # Video acceleration
      libva
      libva-utils
      intel-gpu-tools
    ];

    extraPackages32 = with pkgs.driversi686Linux; [
      intel-vaapi-driver
      intel-media-driver
    ];
  };

  # Environment packages for Intel development and monitoring
  environment.systemPackages = with pkgs; [
    # Intel monitoring and control
    intel-gpu-tools # Intel GPU utilities (intel_gpu_top, etc.)
    libva-utils # VA-API utilities

    # Development tools
    intel-compute-runtime # OpenCL runtime
    oclgrind # OpenCL debugger

    # Video utilities
    libva-utils
    vdpauinfo

    # Performance profiling
    intel-gpu-tools

    # System monitoring
    powertop # Intel power monitoring
    thermald # Thermal management
  ];

  # Environment variables for Intel graphics
  environment.variables = {
    # Video acceleration
    LIBVA_DRIVER_NAME = "iHD"; # Use iHD for modern Intel GPUs
    # LIBVA_DRIVER_NAME = "i965"; # Use i965 for older Intel GPUs
    VDPAU_DRIVER = "va_gl";

    # OpenCL configuration
    OPENCL_VENDOR_PATH = "${pkgs.intel-compute-runtime}/etc/OpenCL/vendors";

    # Mesa configuration for Intel
    MESA_LOADER_DRIVER_OVERRIDE = "iris"; # Use iris driver for modern Intel

    # Wayland optimizations
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
  };

  # Kernel modules and parameters
  boot.kernelModules = [ "i915" ];

  boot.kernelParams = [
    # Intel GPU specific parameters
    "i915.enable_guc=2" # Enable GuC and HuC firmware
    "i915.enable_fbc=1" # Enable framebuffer compression
    "i915.enable_psr=1" # Enable Panel Self Refresh
    "i915.fastboot=1" # Enable fastboot

    # Performance optimizations
    "i915.modeset=1" # Enable kernel modesetting
    "i915.nuclear_pageflip=1" # Enable atomic modesetting

    # Power management
    "i915.enable_rc6=1" # Enable RC6 power saving
    "i915.enable_dc=1" # Enable display C-states
    "i915.disable_power_well=0" # Keep power wells enabled

    # Memory management
    "i915.preliminary_hw_support=1" # Support for newer hardware
  ];

  # Additional kernel configuration for Intel
  boot.kernel.sysctl = {
    # Graphics performance
    "dev.i915.perf_stream_paranoid" = 0;

    # Power management
    "kernel.nmi_watchdog" = 0; # Disable NMI watchdog for power saving
  };

  # Hardware-specific udev rules
  services.udev.extraRules = ''
    # Intel GPU rules
    KERNEL=="renderD*", GROUP="render", MODE="0664"
    KERNEL=="card*", GROUP="video", MODE="0664"

    # Intel-specific device permissions
    SUBSYSTEM=="drm", KERNEL=="renderD128", GROUP="render", MODE="0666"

    # Power management permissions
    KERNEL=="hwmon*", SUBSYSTEM=="hwmon", ACTION=="add", PROGRAM="${pkgs.bash}/bin/bash -c 'readlink -f /sys/class/hwmon/%k/device'", RESULT=="/sys/devices/pci*/*/*/drm/card*/device", RUN+="${pkgs.bash}/bin/bash -c 'chmod 664 /sys/class/hwmon/%k/{temp*_input,fan*_input,pwm*,in*_input}; chgrp users /sys/class/hwmon/%k/{temp*_input,fan*_input,pwm*,in*_input}'"
  '';

  # Power management optimized for Intel
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "powersave"; # Intel CPUs work well with powersave
    powertop.enable = true; # Intel power optimization
  };

  # Intel-specific services
  services = {
    # Thermal management for Intel systems
    thermald = {
      enable = true;
      debug = false;
      configFile = null; # Use default configuration
    };

    intel-gpu-tools.enable = true;

    # Audio configuration optimized for Intel
    pipewire = {
      extraConfig.pipewire = {
        "context.properties" = {
          # Optimize for power efficiency
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 1024;
          "default.clock.min-quantum" = 32;
          "default.clock.max-quantum" = 8192;
        };
      };
    };
  };

  # Gaming configuration for Intel (limited but functional)
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 5; # Less aggressive than discrete GPUs
        ioprio = 4;
        inhibit_screensaver = 1;
        softrealtime = "auto";
      };

      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
      };
    };
  };

  # Additional hardware support
  hardware = {
    # CPU-specific optimizations
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # Audio support
    pulseaudio.support32Bit = true;

    # Bluetooth support
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

  # Intel GPU monitoring service
  systemd.services.intel-gpu-monitor = {
    enable = false; # Enable if you want GPU monitoring
    description = "Intel GPU Monitoring";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.intel-gpu-tools}/bin/intel_gpu_top";
      Restart = "always";
      User = "nobody";
    };
  };

  # Power optimization service
  systemd.services.intel-power-optimization = {
    description = "Intel Power Optimization";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.powertop}/bin/powertop --auto-tune'";
      RemainAfterExit = true;
    };
  };

  # Xorg configuration for Intel
  services.xserver = {
    videoDrivers = [ "modesetting" ]; # Use modesetting driver for Intel
    deviceSection = ''
      Option "DRI" "3"
      Option "TearFree" "true"
      Option "AccelMethod" "glamor"
    '';
  };

  # Wayland configuration
  programs.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
  };

  # Intel-specific optimizations for different generations
  # Uncomment based on your Intel GPU generation

  # # For very old Intel GPUs (pre-Haswell)
  # environment.variables.LIBVA_DRIVER_NAME = "i965";
  # boot.kernelParams = lib.mkAfter [ "i915.preliminary_hw_support=1" ];

  # # For Haswell and newer
  # environment.variables.LIBVA_DRIVER_NAME = "iHD";

  # # For latest Intel Arc GPUs
  # environment.variables.LIBVA_DRIVER_NAME = "iHD";
  # boot.kernelParams = lib.mkAfter [ "i915.force_probe=*" ];

  # Additional packages for Intel development
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
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
      value = "-5"; # Less aggressive than discrete GPUs
    }
  ];
}
