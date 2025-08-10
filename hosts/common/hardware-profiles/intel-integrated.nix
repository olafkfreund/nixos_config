# Intel Integrated Graphics Hardware Profile
# For hosts: samsung, dex5550
# Provides Intel-specific GPU configurations and environment variables

# No parameters needed - pure data structure
{
  gpu = "intel";
  acceleration = "vaapi"; # Intel video acceleration
  videoDrivers = [ "intel" ];

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
