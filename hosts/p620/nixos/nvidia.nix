{ config
, pkgs
, lib
, ...
}: {
  # Hybrid setup: AMD primary for display, NVIDIA for compute/AI only
  # Do NOT add NVIDIA to videoDrivers - keep AMD as primary display

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    nvidiaPersistenced = true;
    open = false;
    nvidiaSettings = false; # No GUI settings needed for AI workloads
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };

  # Graphics support optimized for AI/compute workloads
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      # CUDA support for AI workloads (toolkit only to avoid LICENSE conflicts)
      cudaPackages.cudatoolkit
      # Note: cuDNN installed separately via systemPackages to avoid LICENSE conflicts

      # Vulkan support (useful for some AI frameworks)
      vulkan-validation-layers
      vulkan-loader
      vulkan-tools

      # Video acceleration (minimal set)
      libva-vdpau-driver
      nvidia-vaapi-driver
    ];
  };

  # Environment packages for AI development
  environment.systemPackages = with pkgs; [
    # NVIDIA utilities (nvidia-smi comes with the driver)
    nvtopPackages.nvidia

    # CUDA development tools
    cudaPackages.cuda_nvcc
    cudaPackages.cuda_gdb

    # Deep learning libraries (separate from graphics to avoid LICENSE conflicts)
    cudaPackages.cudnn

    # Performance monitoring
    libva-utils
  ];

  # Environment variables for CUDA
  environment.variables = {
    CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";
    CUDA_ROOT = "${pkgs.cudaPackages.cudatoolkit}";
  };

  # Override LD_LIBRARY_PATH to include both SANE and CUDA libraries
  environment.sessionVariables = {
    LD_LIBRARY_PATH = lib.mkForce "/etc/sane-libs:${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudnn}/lib";
  };

  # Load NVIDIA kernel modules for compute/AI (not display)
  boot.kernelModules = [ "nvidia" "nvidia_uvm" ];

  # Kernel parameters for compute-only operation
  boot.kernelParams = [
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
  ];

  # Ensure NVIDIA modules are available
  hardware.nvidia.forceFullCompositionPipeline = false;

  # Systemd services for NVIDIA persistence
  systemd.services.nvidia-persistenced = {
    description = "NVIDIA Persistence Daemon";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "forking";
      Restart = "always";
      PIDFile = "/var/run/nvidia-persistenced/nvidia-persistenced.pid";
      ExecStart = "${config.boot.kernelPackages.nvidia_x11.persistenced}/bin/nvidia-persistenced --verbose";
      ExecStopPost = "${pkgs.coreutils}/bin/rm -rf /var/run/nvidia-persistenced";
    };
  };
}
