# Intel GPU configuration for server template
# Optimized for basic graphics and compute workloads in headless operation
{ config, pkgs, lib, ... }:

{
  # Intel graphics hardware support for servers
  hardware.graphics = {
    enable = true;
    enable32Bit = false; # Usually not needed for servers
    extraPackages = with pkgs; [
      # Intel-specific packages for compute
      intel-media-driver # Modern Intel GPUs (Broadwell+)
      intel-vaapi-driver # Legacy Intel GPUs
      intel-compute-runtime # OpenCL runtime for compute

      # Minimal video acceleration
      libva
      libva-utils
      intel-gpu-tools
    ];
  };

  # Environment packages for Intel server monitoring
  environment.systemPackages = with pkgs; [
    # Intel monitoring and control
    intel-gpu-tools # Intel GPU utilities (intel_gpu_top, etc.)
    libva-utils # VA-API utilities

    # Development tools for compute
    intel-compute-runtime # OpenCL runtime

    # System monitoring optimized for servers
    powertop # Intel power monitoring
    thermald # Thermal management

    # Hardware diagnostics
    dmidecode # Hardware information
    lshw # Hardware listing
  ];

  # Environment variables for Intel graphics compute
  environment.variables = {
    # Video acceleration (minimal for servers)
    LIBVA_DRIVER_NAME = "iHD"; # Use iHD for modern Intel GPUs
    # LIBVA_DRIVER_NAME = "i965"; # Use i965 for older Intel GPUs

    # OpenCL configuration for compute workloads
    OPENCL_VENDOR_PATH = "${pkgs.intel-compute-runtime}/etc/OpenCL/vendors";

    # Mesa configuration for Intel
    MESA_LOADER_DRIVER_OVERRIDE = "iris"; # Use iris driver for modern Intel

    # Disable GUI-related optimizations
    MOZ_ENABLE_WAYLAND = "0"; # Disable for servers
    QT_QPA_PLATFORM = "minimal"; # Minimal platform for servers
  };

  # Kernel modules and parameters for server use
  boot.kernelModules = [ "i915" ];

  boot.kernelParams = [
    # Intel GPU specific parameters optimized for servers
    "i915.enable_guc=2" # Enable GuC and HuC firmware
    "i915.enable_fbc=1" # Enable framebuffer compression
    "i915.fastboot=1" # Enable fastboot

    # Performance optimizations for compute
    "i915.modeset=1" # Enable kernel modesetting
    "i915.nuclear_pageflip=1" # Enable atomic modesetting

    # Power management for servers
    "i915.enable_rc6=1" # Enable RC6 power saving
    "i915.enable_dc=1" # Enable display C-states
    "i915.disable_power_well=0" # Keep power wells enabled

    # Memory and compute optimizations
    "i915.preliminary_hw_support=1" # Support for newer hardware
    "i915.enable_hangcheck=1" # Enable hang detection
  ];

  # Kernel configuration for Intel servers
  boot.kernel.sysctl = {
    # Graphics performance for compute
    "dev.i915.perf_stream_paranoid" = 0;

    # Power management optimizations
    "kernel.nmi_watchdog" = 0; # Disable NMI watchdog for power saving

    # Memory management for compute workloads
    "vm.overcommit_memory" = 1;
    "vm.overcommit_ratio" = 100;
  };

  # Hardware-specific udev rules for compute access
  services.udev.extraRules = ''
    # Intel GPU rules for compute access
    KERNEL=="renderD*", GROUP="render", MODE="0664"
    KERNEL=="card*", GROUP="video", MODE="0664"
    
    # Intel-specific device permissions for compute
    SUBSYSTEM=="drm", KERNEL=="renderD128", GROUP="render", MODE="0666"
    
    # Power management permissions for monitoring
    KERNEL=="hwmon*", SUBSYSTEM=="hwmon", ACTION=="add", PROGRAM="${pkgs.bash}/bin/bash -c 'readlink -f /sys/class/hwmon/%k/device'", RESULT=="/sys/devices/pci*/*/*/drm/card*/device", RUN+="${pkgs.bash}/bin/bash -c 'chmod 664 /sys/class/hwmon/%k/{temp*_input,fan*_input,pwm*,in*_input}; chgrp users /sys/class/hwmon/%k/{temp*_input,fan*_input,pwm*,in*_input}'"
  '';

  # Power management optimized for Intel servers
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "powersave"; # Intel CPUs work well with powersave
    powertop.enable = true; # Intel power optimization
  };

  # Thermal management for Intel systems
  services.thermald = {
    enable = true;
    debug = false;
    configFile = null; # Use default configuration
  };

  # Intel-specific services for servers
  services.intel-gpu-tools.enable = lib.mkDefault false; # Enable if needed

  # Disable gaming and audio for servers
  programs.gamemode.enable = lib.mkForce false;
  services.pipewire.enable = lib.mkForce false;
  hardware.pulseaudio.enable = lib.mkForce false;
  sound.enable = lib.mkForce false;

  # Minimal hardware support for servers
  hardware = {
    # CPU-specific optimizations
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

    # Disable unnecessary hardware for servers
    bluetooth.enable = lib.mkDefault false;
    pulseaudio.enable = lib.mkForce false;

    # Graphics support for compute
    graphics.driSupport = true;
    graphics.driSupport32Bit = false; # Not needed for servers
  };

  # Intel GPU monitoring service (optional)
  systemd.services.intel-gpu-monitor = {
    enable = false; # Enable if you want GPU monitoring
    description = "Intel GPU Monitoring for Servers";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.intel-gpu-tools}/bin/intel_gpu_top -s 1000";
      Restart = "always";
      User = "nobody";
    };
  };

  # Power optimization service for servers
  systemd.services.intel-power-optimization = {
    description = "Intel Power Optimization for Servers";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.powertop}/bin/powertop --auto-tune'";
      RemainAfterExit = true;
    };
  };

  # Thermal monitoring service (optional)
  systemd.services.intel-thermal-monitor = {
    enable = false; # Enable if you need thermal monitoring
    description = "Intel Thermal Monitoring";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash -c 'while true; do ${pkgs.lm_sensors}/bin/sensors; sleep 60; done'";
      Restart = "always";
      User = "nobody";
    };
  };

  # Disable X11 and display services
  services.xserver.enable = lib.mkForce false;
  programs.hyprland.enable = lib.mkForce false;
  programs.sway.enable = lib.mkForce false;

  # Security and performance for compute workloads
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
      value = "-5"; # Less aggressive than workstations
    }
    {
      domain = "@users";
      item = "memlock";
      type = "-";
      value = "unlimited"; # Important for compute workloads
    }
    {
      domain = "@users";
      item = "nofile";
      type = "-";
      value = "65536"; # High file descriptor limit
    }
  ];

  # Intel-specific optimizations for different generations
  # Uncomment based on your Intel GPU generation

  # # For very old Intel GPUs (pre-Haswell)
  # environment.variables.LIBVA_DRIVER_NAME = "i965";
  # boot.kernelParams = lib.mkAfter [ "i915.preliminary_hw_support=1" ];

  # # For Haswell and newer (most common)
  # environment.variables.LIBVA_DRIVER_NAME = "iHD";

  # # For latest Intel Arc GPUs (if using on servers)
  # environment.variables.LIBVA_DRIVER_NAME = "iHD";
  # boot.kernelParams = lib.mkAfter [ "i915.force_probe=*" ];

  # Container support for Intel compute (if Docker enabled)
  virtualisation.docker.daemon.settings = lib.mkIf config.virtualisation.docker.enable {
    # Intel GPU device support for containers
    default-runtime = "runc";
    runtimes = {
      intel = {
        path = "${pkgs.runc}/bin/runc";
        runtimeArgs = [ ];
      };
    };
  };

  # Environment optimization for server workloads
  environment.variables = lib.mkMerge [
    # Disable GUI-related variables
    { WLR_NO_HARDWARE_CURSORS = "1"; }
    { LIBGL_ALWAYS_SOFTWARE = "0"; } # Allow hardware for compute

    # Optimize for compute workloads
    { INTEL_DEBUG = ""; } # Disable debugging overhead
    { I915_DEBUG = ""; } # Disable debugging overhead

    # Set compute-focused configuration
    { MESA_GLSL_CACHE_DISABLE = "false"; } # Enable shader cache
    { MESA_GLSL_CACHE_MAX_SIZE = "100M"; } # Reasonable cache size
  ];

  # Intel GPU frequency scaling for servers
  systemd.services.intel-gpu-frequency = {
    enable = false; # Enable if you need manual frequency control
    description = "Intel GPU Frequency Control";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      # Set to maximum frequency for compute workloads
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo 1 > /sys/class/drm/card0/gt_max_freq_mhz'";
      RemainAfterExit = true;
    };
  };

  # Disable unnecessary services for headless operation
  systemd.services = {
    accounts-daemon.enable = lib.mkForce false;
    rtkit-daemon.enable = lib.mkForce false;
    alsa-state.enable = lib.mkForce false;
  };

  # Minimal font configuration for servers
  fonts = {
    enableDefaultPackages = false;
    packages = with pkgs; [
      terminus_font
      dejavu_fonts
    ];
  };

  # Console configuration
  console = {
    enable = true;
    font = "Lat2-Terminus16";
    useXkbConfig = false;
  };
}
