# Intel Integrated Graphics Hardware Profile
# For hosts: samsung, dex5550
# Provides Intel-specific GPU configurations and environment variables
# Uses modesetting driver for modern Intel GPUs (12th gen and newer)

# No parameters needed - pure data structure
{
  gpu = "modesetting";
  acceleration = "vaapi"; # Intel video acceleration
  videoDrivers = [ "modesetting" ];

  # Intel-specific environment variables
  extraEnvironment = {
    # Intel graphics optimization
    MESA_LOADER_DRIVER_OVERRIDE = "iris";
    INTEL_DEBUG = "norbc";
    LIBVA_DRIVER_NAME = "iHD";
  };

  # Intel-specific user groups (if any additional groups needed)
  extraGroups = [
    # Add Intel-specific groups here if needed
  ];

  # Intel-specific packages or configurations
  hardwareConfig = {
    # Intel integrated graphics optimizations
    enableVAAPI = true;
    enableOpenGL = true;
    enableIntelMedia = true;
  };
}
