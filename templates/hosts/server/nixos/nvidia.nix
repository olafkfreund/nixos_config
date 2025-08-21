# NVIDIA GPU configuration for server template
# Optimized for compute workloads and headless operation
{ config
, pkgs
, lib
, ...
}: {
  # NVIDIA hardware configuration for compute
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    nvidiaPersistenced = true;
    open = false; # Use proprietary driver for better compute support
    nvidiaSettings = false; # Disable GUI settings for servers
    package = config.boot.kernelPackages.nvidiaPackages.production; # Stable driver

    # Disable Prime for servers (usually single GPU)
    prime.offload.enable = lib.mkForce false;
  };

  # Graphics support optimized for compute
  hardware.graphics = {
    enable = true;
    enable32Bit = false; # Usually not needed for servers
    extraPackages = with pkgs; [
      # CUDA support for compute workloads
      cudaPackages.cudatoolkit
      cudaPackages.cudnn

      # Video acceleration (minimal)
      libva-vdpau-driver
      nvidia-vaapi-driver

      # OpenGL for compute
      libGL
      libGLU
    ];
  };

  # Environment packages for NVIDIA server development
  environment.systemPackages = with pkgs; [
    # NVIDIA utilities for servers
    nvtopPackages.nvidia # GPU monitoring

    # CUDA development tools
    cudaPackages.cuda_nvcc # NVCC compiler
    cudaPackages.cuda_gdb # CUDA debugger
    cudaPackages.nsight_compute # Profiling

    # Deep learning libraries
    cudaPackages.cudnn
    cudaPackages.cutensor
    cudaPackages.nccl

    # Minimal video utilities
    libva-utils # VA-API utilities
    vdpauinfo # VDPAU information

    # System monitoring
    nvidia-smi # NVIDIA system management

    # Optional CUDA development tools
    cuda-samples
    nsight-systems
    nsight-compute
  ];

  # Environment variables for CUDA compute
  environment.variables = {
    CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";
    CUDA_ROOT = "${pkgs.cudaPackages.cudatoolkit}";
    CUDNN_PATH = "${pkgs.cudaPackages.cudnn}";

    # Video acceleration (minimal)
    LIBVA_DRIVER_NAME = "nvidia";
    VDPAU_DRIVER = "nvidia";

    # OpenGL for compute
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # Disable GUI-related optimizations
    __GL_SHADER_DISK_CACHE = "0"; # Disable for servers
    WLR_NO_HARDWARE_CURSORS = "1";
    NIXOS_OZONE_WL = "0"; # Disable Wayland for servers

    # Compute optimizations
    CUDA_CACHE_DISABLE = "0"; # Enable CUDA cache
    CUDA_CACHE_MAXSIZE = "1073741824"; # 1GB cache
    NVIDIA_DRIVER_CAPABILITIES = "compute,utility";
    NVIDIA_REQUIRE_CUDA = "cuda>=11.0";
    __GL_SYNC_TO_VBLANK = "0"; # Disable VSync for compute
    __GL_ALLOW_UNOFFICIAL_PROTOCOL = "1";
  };

  # Session variables for compute development
  environment.sessionVariables = {
    LD_LIBRARY_PATH = lib.mkAfter "${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudnn}/lib";
    PATH = lib.mkAfter "${pkgs.cudaPackages.cudatoolkit}/bin";
  };

  # Load NVIDIA kernel modules for compute
  boot.kernelModules = [ "nvidia" "nvidia_uvm" "nvidia_drm" "nvidia_modeset" ];

  # Kernel parameters optimized for server compute
  boot.kernelParams = [
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    "nvidia-drm.modeset=1"

    # Compute optimizations
    "nvidia.NVreg_UsePageAttributeTable=1"
    "nvidia.NVreg_InitializeSystemMemoryAllocations=0"

    # Server optimizations
    "nvidia.NVreg_TemporaryFilePath=/tmp"
    "nvidia.NVreg_EnablePCIeGen3=1"
  ];

  # Hardware-specific udev rules for compute access
  services.udev.extraRules = ''
    # NVIDIA device permissions for compute
    KERNEL=="nvidia", RUN+="${pkgs.bash}/bin/bash -c 'mknod -m 666 /dev/nvidiactl c $$(grep nvidia-frontend /proc/devices | cut -d \\  -f 1) 255'"
    KERNEL=="nvidia_modeset", RUN+="${pkgs.bash}/bin/bash -c 'mknod -m 666 /dev/nvidia-modeset c $$(grep nvidia-frontend /proc/devices | cut -d \\  -f 1) 254'"
    KERNEL=="nvidia_uvm", RUN+="${pkgs.bash}/bin/bash -c 'mknod -m 666 /dev/nvidia-uvm c $$(grep nvidia-uvm /proc/devices | cut -d \\  -f 1) 0'"
    KERNEL=="nvidia_uvm", RUN+="${pkgs.bash}/bin/bash -c 'mknod -m 666 /dev/nvidia-uvm-tools c $$(grep nvidia-uvm /proc/devices | cut -d \\  -f 1) 1'"

    # GPU device permissions for compute workloads
    KERNEL=="card*", SUBSYSTEM=="drm", DRIVERS=="nvidia", MODE="0666"
    KERNEL=="renderD*", SUBSYSTEM=="drm", DRIVERS=="nvidia", MODE="0666"
  '';

  # Systemd services for NVIDIA server optimization
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

  # Disable gaming optimizations for servers
  programs.gamemode.enable = lib.mkForce false;

  # Container support for NVIDIA compute
  hardware.nvidia-container-toolkit.enable = true;
  virtualisation.docker.enableNvidia = true;

  # Power management for server workloads
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "performance"; # High performance for compute
  };

  # Disable audio for headless servers
  services.pipewire.enable = lib.mkForce false;
  hardware.pulseaudio.enable = lib.mkForce false;
  sound.enable = lib.mkForce false;

  # Security and performance tweaks for compute
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
      value = "unlimited"; # Important for CUDA workloads
    }
    {
      domain = "@users";
      item = "nofile";
      type = "-";
      value = "65536"; # High file descriptor limit
    }
  ];

  # NVIDIA compute optimization service
  systemd.services.nvidia-compute-optimization = {
    description = "NVIDIA Compute Optimization for Servers";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c '${config.boot.kernelPackages.nvidia_x11}/bin/nvidia-smi -pm 1; ${config.boot.kernelPackages.nvidia_x11}/bin/nvidia-smi -c 0'";
      RemainAfterExit = true;
    };
  };

  # Optional power limiting service for servers
  systemd.services.nvidia-powerlimit = {
    enable = false; # Enable if you need power limiting
    description = "NVIDIA GPU Power Limit for Servers";
    wantedBy = [ "multi-user.target" ];
    after = [ "nvidia-persistenced.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${config.boot.kernelPackages.nvidia_x11}/bin/nvidia-smi -pl 250"; # Adjust power limit as needed
      RemainAfterExit = true;
    };
  };

  # Disable X11 and display services
  services.xserver.enable = lib.mkForce false;
  programs.hyprland.enable = lib.mkForce false;
  programs.sway.enable = lib.mkForce false;

  # NVIDIA monitoring service (optional)
  systemd.services.nvidia-monitor = {
    enable = false; # Enable if you want continuous monitoring
    description = "NVIDIA GPU Monitoring Service";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash -c 'while true; do ${config.boot.kernelPackages.nvidia_x11}/bin/nvidia-smi; sleep 60; done'";
      Restart = "always";
      User = "nobody";
    };
  };

  # Docker configuration for NVIDIA compute
  virtualisation.docker.daemon.settings = lib.mkIf config.virtualisation.docker.enable {
    default-runtime = "nvidia";
    runtimes = {
      nvidia = {
        path = "${pkgs.nvidia-docker}/bin/nvidia-container-runtime";
        runtimeArgs = [ ];
      };
    };
  };


  # Kernel configuration for NVIDIA compute
  boot.kernel.sysctl = {
    # Memory overcommit for large compute applications
    "vm.overcommit_memory" = 1;
    "vm.overcommit_ratio" = 100;

    # NUMA optimizations for multi-GPU systems
    "kernel.numa_balancing" = 0;
  };


  # Temperature monitoring for server workloads
  systemd.services.nvidia-thermal-monitor = {
    enable = false; # Enable if you need thermal monitoring
    description = "NVIDIA Thermal Monitoring";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.bash}/bin/bash -c 'while true; do temp=$(${config.boot.kernelPackages.nvidia_x11}/bin/nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits); echo \"GPU Temperature: $temp°C\"; if [ $temp -gt 85 ]; then echo \"WARNING: GPU temperature high!\"; fi; sleep 30; done'";
      Restart = "always";
      User = "nobody";
    };
  };
}
