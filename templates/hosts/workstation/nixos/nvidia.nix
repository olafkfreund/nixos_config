# NVIDIA GPU configuration for workstation template
{ config
, pkgs
, lib
, ...
}: {
  # NVIDIA hardware configuration
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    nvidiaPersistenced = true;
    open = false; # Use proprietary driver (better for gaming/AI)
    nvidiaSettings = true; # GUI settings tool
    package = config.boot.kernelPackages.nvidiaPackages.latest;

    # Prime.offload for laptops with dual GPUs (uncomment if needed)
    # prime = {
    #   offload = {
    #     enable = true;
    #     enableOffloadCmd = true;
    #   };
    #   intelBusId = "PCI:0:2:0";   # lspci | grep VGA
    #   nvidiaBusId = "PCI:1:0:0";  # lspci | grep NVIDIA
    # };
  };

  # Graphics support optimized for NVIDIA
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      # CUDA support for AI workloads
      cudaPackages.cudatoolkit
      cudaPackages.cudnn

      # Vulkan support
      vulkan-validation-layers
      vulkan-loader
      vulkan-tools

      # Video acceleration
      libva-vdpau-driver
      nvidia-vaapi-driver
      vaapiVdpau

      # OpenGL and compute
      libGL
      libGLU

      # NVIDIA specific
      nvidia-vaapi-driver
    ];
  };

  # Environment packages for NVIDIA development
  environment.systemPackages = with pkgs; [
    # NVIDIA utilities
    nvtopPackages.nvidia # GPU monitoring
    nvidia-system-monitor-qt # GUI monitoring

    # CUDA development tools
    cudaPackages.cuda_nvcc # NVCC compiler
    cudaPackages.cuda_gdb # CUDA debugger
    cudaPackages.nsight_compute # Profiling
    cudaPackages.nsight_systems # System analysis
    nsight-compute
    nsight-systems
    cuda-samples

    # Deep learning libraries
    cudaPackages.cudnn
    cudaPackages.cutensor
    cudaPackages.nccl

    # Video utilities
    libva-utils # VA-API utilities
    vdpauinfo # VDPAU information
    nvidia-vaapi-driver

    # Vulkan utilities
    vulkan-tools
    vulkan-validation-layers

    # Performance monitoring
    gwe # GPU control GUI
  ];

  # Environment variables for CUDA
  environment.variables = {
    CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";
    CUDA_ROOT = "${pkgs.cudaPackages.cudatoolkit}";
    CUDNN_PATH = "${pkgs.cudaPackages.cudnn}";

    # OpenGL and video
    LIBVA_DRIVER_NAME = "nvidia";
    VDPAU_DRIVER = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # Wayland compatibility
    WLR_NO_HARDWARE_CURSORS = "1";
    NIXOS_OZONE_WL = "1";

    # Gaming optimizations
    __GL_SHADER_DISK_CACHE = "1";
    __GL_SHADER_DISK_CACHE_PATH = "/tmp/nvidia-shader-cache";
    __GL_SHADER_DISK_CACHE_SIZE = "1073741824"; # 1GB
  };

  # Session variables for development
  environment.sessionVariables = {
    LD_LIBRARY_PATH = lib.mkAfter "${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudnn}/lib";
    PATH = lib.mkAfter "${pkgs.cudaPackages.cudatoolkit}/bin";
  };

  # Load NVIDIA kernel modules
  boot.kernelModules = [ "nvidia" "nvidia_uvm" "nvidia_drm" "nvidia_modeset" ];

  # Kernel parameters for NVIDIA
  boot.kernelParams = [
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"

    # Gaming optimizations
    "nvidia.NVreg_UsePageAttributeTable=1"
    "nvidia.NVreg_InitializeSystemMemoryAllocations=0"

    # Wayland support
    "nvidia_drm.modeset=1"
  ];

  # Hardware-specific udev rules
  services.udev.extraRules = ''
    # NVIDIA device permissions
    KERNEL=="nvidia", RUN+="${pkgs.bash}/bin/bash -c 'mknod -m 666 /dev/nvidiactl c $$(grep nvidia-frontend /proc/devices | cut -d \  -f 1) 255'"
    KERNEL=="nvidia_modeset", RUN+="${pkgs.bash}/bin/bash -c 'mknod -m 666 /dev/nvidia-modeset c $$(grep nvidia-frontend /proc/devices | cut -d \  -f 1) 254'"
    KERNEL=="nvidia_uvm", RUN+="${pkgs.bash}/bin/bash -c 'mknod -m 666 /dev/nvidia-uvm c $$(grep nvidia-uvm /proc/devices | cut -d \  -f 1) 0'"
    KERNEL=="nvidia_uvm", RUN+="${pkgs.bash}/bin/bash -c 'mknod -m 666 /dev/nvidia-uvm-tools c $$(grep nvidia-uvm /proc/devices | cut -d \  -f 1) 1'"

    # GPU scheduling
    KERNEL=="card*", SUBSYSTEM=="drm", DRIVERS=="nvidia", RUN+="${pkgs.bash}/bin/bash -c 'echo 1 > /sys/class/drm/%k/device/power/control'"
  '';

  # Systemd services for NVIDIA optimization
  systemd.services.nvidia-persistenced = {
    description = "NVIDIA Persistence Daemon";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "forking";
      Restart = "always";
      PIDFile = "/var/run/nvidia-persistenced/nvidia-persistenced.pid";
      ExecStart = "${config.boot.kernelPackages.nvidia_x11.persistenced}/bin/nvidia-persistenced --verbose";
      ExecStopPost = "${pkgs.coreutils}/bin/rm -rf /var/run/nvidia-persistenced";
      User = "nvidia-persistenced";
      Group = "nvidia-persistenced";
    };
  };

  # Create nvidia-persistenced user
  users.users.nvidia-persistenced = {
    isSystemUser = true;
    group = "nvidia-persistenced";
  };
  users.groups.nvidia-persistenced = { };

  # Gaming optimizations with GameMode
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
        nvidia_powerlimit = "max";
      };

      custom = {
        start = "${pkgs.bash}/bin/bash -c 'nvidia-settings -a GPUPowerMizerMode=1'";
        end = "${pkgs.bash}/bin/bash -c 'nvidia-settings -a GPUPowerMizerMode=0'";
      };
    };
  };

  # Container support for NVIDIA
  hardware.nvidia-container-toolkit.enable = true;
  virtualisation.docker.enableNvidia = true;

  # Power management
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "performance"; # For high-end systems
  };

  # Audio configuration for NVIDIA HDMI
  services.pipewire = {
    extraConfig.pipewire = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.quantum" = 1024;
        "default.clock.min-quantum" = 32;
        "default.clock.max-quantum" = 8192;
      };
    };
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

  # Additional services for monitoring and control
  systemd.services.nvidia-powerlimit = {
    enable = false; # Enable if you need power limiting
    description = "NVIDIA GPU Power Limit";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'nvidia-smi -pl 300'"; # Set 300W limit
      RemainAfterExit = true;
    };
  };

  # Temperature monitoring and fan curves
  systemd.services.nvidia-fan-curve = {
    enable = false; # Enable if you need custom fan curves
    description = "NVIDIA Fan Curve";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.nvidia-system-monitor-qt}/bin/nvidia-system-monitor";
      RemainAfterExit = true;
    };
  };

  # Xorg configuration for multiple monitors
  services.xserver = {
    videoDrivers = [ "nvidia" ];
    screenSection = ''
      Option "metamodes" "nvidia-auto-select +0+0 {ForceFullCompositionPipeline=On}"
      Option "AllowIndirectGLXProtocol" "off"
      Option "TripleBuffer" "on"
    '';
  };

  # Wayland configuration
  programs.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
  };

}
