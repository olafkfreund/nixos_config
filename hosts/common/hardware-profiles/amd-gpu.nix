# AMD GPU Hardware Profile
# For hosts: p620
# Provides AMD-specific GPU configurations and environment variables

# No parameters needed - pure data structure
{
  gpu = "amd";
  acceleration = "rocm"; # For ollama and AMD GPU acceleration
  videoDrivers = [ "amdgpu" ];

  # AMD-specific environment variables
  extraEnvironment = {
    # AMD-specific variables (commented out as they may not be needed)
    # ROC_ENABLE_PRE_VEGA = "1";
    # HSA_OVERRIDE_GFX_VERSION = "11.0.0";
    # LIBVA_DRIVER_NAME = "radeonsi";
  };

  # AMD-specific user groups (if any additional groups needed)
  extraGroups = [
    # Add AMD-specific groups here if needed
  ];

  # AMD-specific packages or configurations can be added here
  hardwareConfig = {
    # AMD GPU requires specific drivers and ROCm support
    enableROCm = true;
    enableOpenGL = true;
  };
}
