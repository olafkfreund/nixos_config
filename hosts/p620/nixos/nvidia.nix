{
  config,
  pkgs,
  ...
}: {
  # Hybrid setup: AMD primary for display, NVIDIA for compute/AI
  # Do NOT add NVIDIA to videoDrivers - keep AMD as primary display
  
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    nvidiaPersistenced = true;
    open = false;
    nvidiaSettings = false;  # No GUI settings needed for AI workloads
    package = config.boot.kernelPackages.nvidiaPackages.latest;
    
    # Prime configuration for hybrid setup
    prime = {
      # Allow NVIDIA to be used for compute while AMD handles display
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      # Bus IDs from lspci output
      amdgpuBusId = "PCI:227:0:0";    # e3:00.0 -> 227:0:0 in decimal
      nvidiaBusId = "PCI:193:0:0";    # c1:00.0 -> 193:0:0 in decimal
    };
  };

  # Graphics support optimized for AI/compute workloads
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      # CUDA support for AI workloads
      cudaPackages.cudatoolkit
      cudaPackages.cudnn
      cudaPackages.tensorrt
      
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
    # NVIDIA utilities
    nvidia-smi
    nvtop
    
    # CUDA development tools
    cudaPackages.cuda_nvcc
    cudaPackages.cuda_gdb
    
    # Performance monitoring
    libva-utils
  ];

  # Environment variables for CUDA
  environment.variables = {
    CUDA_PATH = "${pkgs.cudaPackages.cudatoolkit}";
    CUDA_ROOT = "${pkgs.cudaPackages.cudatoolkit}";
    LD_LIBRARY_PATH = "${pkgs.cudaPackages.cudatoolkit}/lib:${pkgs.cudaPackages.cudnn}/lib";
  };

  # Kernel modules
  boot.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
  
  # Kernel parameters for headless operation
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
  ];

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