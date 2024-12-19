{...}: {
  wayland.windowManager.hyprland.extraConfig = ''
    # Environment variables for Hyprland configuration
    env = GBM_BACKEND,nvidia-drm           # Use NVIDIA GBM backend
    env = WLR_DRM_NO_ATOMIC,1              # Disable atomic mode setting for wlroots
    env = WLR_NO_HARDWARE_CURSORS,1        # Disable hardware cursors
    env = LIBVA_DRIVER_NAME,nvidia         # Set VAAPI driver to NVIDIA
    env = __GLX_VENDOR_LIBRARY_NAME,nvidia  # Set GLX vendor library to NVIDIA
    env = __GL_GSYNC_ALLOWED,1             # Enable GSync for NVIDIA
    env = NVD_BACKEND,direct               # Enable direct mode for NVIDIA
  '';
}
