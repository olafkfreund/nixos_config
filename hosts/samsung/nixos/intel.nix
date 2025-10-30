{ pkgs, ... }: {
  nixpkgs.config.packageOverrides = pkgs: {
    intel-vaapi-driver = pkgs.intel-vaapi-driver.override { enableHybridCodec = true; };
  };

  # OpenGL
  hardware.graphics = {
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      libva-vdpau-driver
      # libvdpau-va-gl removed - old unmaintained package with CMake compatibility issues
      # Modern Intel systems work perfectly with intel-media-driver and intel-vaapi-driver
    ];
  };
}
