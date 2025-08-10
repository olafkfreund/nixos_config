# NVIDIA GPU Hardware Profile
# For hosts: p510, razer, hp
# Provides NVIDIA-specific GPU configurations and environment variables

# No parameters needed - pure data structure
{
  gpu = "nvidia";
  acceleration = "cuda"; # For ollama and NVIDIA GPU acceleration
  videoDrivers = [ "nvidia" ];

  # NVIDIA-specific environment variables
  extraEnvironment = {
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    NVD_BACKEND = "direct";
  };

  # NVIDIA-specific user groups (if any additional groups needed)
  extraGroups = [
    # Add NVIDIA-specific groups here if needed
  ];

  # NVIDIA-specific packages or configurations
  hardwareConfig = {
    # NVIDIA GPU requires specific drivers and CUDA support
    enableCUDA = true;
    enableOpenGL = true;
    enableNvidiaContainerToolkit = true;
  };
}
