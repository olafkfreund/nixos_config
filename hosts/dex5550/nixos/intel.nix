{ pkgs, ... }: {
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  };

  # OpenGL
  hardware.graphics = {
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiIntel
      vaapiVdpau
      # libvdpau-va-gl removed - old unmaintained package with CMake compatibility issues
      # Modern Intel systems work perfectly with intel-media-driver and vaapiIntel
    ];
  };
}
