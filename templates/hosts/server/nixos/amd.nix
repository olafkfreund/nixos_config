# AMD GPU configuration for server template
# Optimized for compute workloads and headless operation
{ config, pkgs, lib, ... }:

{
  # AMD GPU hardware support for compute
  hardware.graphics = {
    enable = true;
    enable32Bit = false; # Usually not needed for servers
    extraPackages = with pkgs; [
      # ROCm packages for AI/ML workloads
      rocmPackages.rocm-runtime
      rocmPackages.rocminfo
      rocmPackages.rocm-smi
      rocmPackages.clr.icd # ROCm OpenCL driver

      # Video acceleration (minimal)
      libva
      libvdpau-va-gl
    ];
  };

  # Environment packages for AMD server monitoring
  environment.systemPackages = with pkgs; [
    # AMD monitoring and control
    radeontop # AMD GPU monitoring
    rocmPackages.rocm-smi # ROCm system management
    rocmPackages.rocminfo # ROCm information

    # Development tools for compute workloads
    rocmPackages.hip # HIP runtime
    rocmPackages.hipcc # HIP compiler

    # Performance profiling
    rocmPackages.rocprofiler
    rocmPackages.roctracer
  ];

  # Environment variables for AMD ROCm compute
  environment.variables = {
    # ROCm configuration
    ROC_ENABLE_PRE_VEGA = "1";
    HCC_AMDGPU_TARGET = "gfx1100"; # Adjust based on your GPU
    HSA_OVERRIDE_GFX_VERSION = "11.0.0"; # Adjust based on your GPU

    # OpenCL configuration
    OPENCL_VENDOR_PATH = "${pkgs.rocmPackages.clr.icd}/etc/OpenCL/vendors";

    # Video acceleration (minimal)
    LIBVA_DRIVER_NAME = "radeonsi";

    # Disable GUI-related variables
    LIBGL_ALWAYS_SOFTWARE = "0"; # Hardware acceleration for compute
  };

  # Session variables for compute workloads
  environment.sessionVariables = {
    ROCM_PATH = "${pkgs.rocmPackages.rocm-runtime}";
    HIP_PATH = "${pkgs.rocmPackages.hip}";
    LD_LIBRARY_PATH = lib.mkAfter "${pkgs.rocmPackages.rocm-runtime}/lib:${pkgs.rocmPackages.hip}/lib";
  };

  # Kernel modules and parameters for server use
  boot.kernelModules = [ "amdgpu" ];

  boot.kernelParams = [
    # AMD GPU specific parameters
    "amdgpu.si_support=1" # Southern Islands support
    "amdgpu.cik_support=1" # Sea Islands support
    "radeon.si_support=0" # Disable radeon for SI
    "radeon.cik_support=0" # Disable radeon for CIK

    # Performance and features for compute
    "amdgpu.gpu_recovery=1" # Enable GPU recovery
    "amdgpu.ppfeaturemask=0xffffffff" # Enable all PowerPlay features

    # Memory management
    "amdgpu.vm_fragment_size=9" # Optimize VM fragments

    # Display configuration (minimal for servers)
    "amdgpu.dc=1" # Enable Display Core
    "amdgpu.dpm=1" # Enable Dynamic Power Management

    # Server optimizations
    "amdgpu.nomodeset=0" # Allow modesetting for basic display
  ];

  # Kernel configuration for compute performance
  boot.kernel.sysctl = {
    # Memory overcommit for large compute applications
    "vm.overcommit_memory" = 1;
    "vm.overcommit_ratio" = 100;

    # GPU-related optimizations
    "dev.i915.perf_stream_paranoid" = 0;
  };

  # Hardware-specific udev rules for compute access
  services.udev.extraRules = ''
    # AMD GPU rules for compute
    KERNEL=="renderD*", GROUP="render", MODE="0664"
    KERNEL=="card*", GROUP="video", MODE="0664"
    
    # ROCm device permissions for compute workloads
    SUBSYSTEM=="drm", KERNEL=="renderD128", GROUP="render", MODE="0666"
    SUBSYSTEM=="kfd", KERNEL=="kfd", GROUP="render", MODE="0666"
    
    # Power management permissions for monitoring
    KERNEL=="hwmon*", SUBSYSTEM=="hwmon", DRIVERS=="amdgpu", GROUP="users", MODE="0664"
  '';

  # Power management optimized for server workloads
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "schedutil"; # Better for AMD Ryzen servers
  };

  # Disable gaming-specific optimizations
  programs.gamemode.enable = lib.mkForce false;

  # Disable audio for headless servers
  services.pipewire.enable = lib.mkForce false;
  hardware.pulseaudio.enable = lib.mkForce false;
  sound.enable = lib.mkForce false;

  # Minimal hardware support for servers
  hardware = {
    graphics.driSupport = true;
    graphics.driSupport32Bit = false; # Not needed for servers

    # Disable unnecessary hardware for servers
    bluetooth.enable = lib.mkDefault false;
    pulseaudio.enable = lib.mkForce false;
  };

  # Security and performance tweaks for compute workloads
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

  # Systemd services for AMD server optimization
  systemd.services.amd-compute-optimization = {
    description = "AMD Compute Optimization for Servers";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo performance > /sys/class/drm/card*/device/power_dpm_force_performance_level'";
      RemainAfterExit = true;
    };
  };

  # ROCm service for compute workloads
  systemd.services.rocm-initialization = {
    description = "ROCm Initialization for Compute";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.rocmPackages.rocminfo}/bin/rocminfo";
      RemainAfterExit = true;
      User = "nobody";
    };
  };

  # Disable X11 and display services
  services.xserver.enable = lib.mkForce false;
  programs.hyprland.enable = lib.mkForce false;
  programs.sway.enable = lib.mkForce false;

  # Container support for AMD GPU compute
  hardware.nvidia-container-toolkit.enable = lib.mkForce false;
  virtualisation.docker.enableNvidia = lib.mkForce false;

  # AMD-specific Docker configuration (if Docker is enabled)
  virtualisation.docker.daemon.settings = lib.mkIf config.virtualisation.docker.enable {
    # ROCm device support for containers
    default-runtime = "runc";
    runtimes = {
      rocm = {
        path = "${pkgs.runc}/bin/runc";
        runtimeArgs = [ ];
      };
    };
  };

  # Environment optimization for server workloads
  environment.variables = lib.mkMerge [
    # Disable GUI acceleration attempts
    { WLR_NO_HARDWARE_CURSORS = "1"; }
    { LIBGL_ALWAYS_SOFTWARE = "0"; } # Allow hardware for compute

    # Optimize for compute workloads
    { AMD_DEBUG = ""; } # Disable debugging overhead
    { R600_DEBUG = ""; } # Disable debugging overhead

    # Set compute-focused driver preferences
    { AMD_VULKAN_ICD = "RADV"; }
    { RADV_PERFTEST = ""; } # Disable experimental features for stability
  ];

  # Monitoring service for AMD GPU (optional)
  systemd.services.amd-gpu-monitor = {
    enable = false; # Enable if you want continuous monitoring
    description = "AMD GPU Monitoring Service";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.radeontop}/bin/radeontop -d -";
      Restart = "always";
      User = "nobody";
    };
  };

  # Optimize for headless compute workloads
  boot.kernelParams = lib.mkAfter [
    "amdgpu.runpm=0" # Disable runtime PM for stability
    "amdgpu.bapm=0" # Disable bidirectional power management
  ];
}
