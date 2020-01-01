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
    env = __NV_PRIME_RENDER_OFFLOAD,1      # Enable NVIDIA Prime render offload
    env = __NV_PRIME_RENDER_OFFLOAD_PROVIDER,NVIDIA-G0  # Set NVIDIA as offload provider
    env = WLR_RENDERER,vulkan              # Use Vulkan renderer
    env = EGL_PLATFORM,wayland             # Force EGL Wayland platform
    env = NIXOS_OZONE_WL,1                 # Enable Ozone Wayland for Electron apps
    env = MOZ_ENABLE_WAYLAND,1             # Enable Wayland for Firefox
    env = QT_QPA_PLATFORM,wayland         # Qt Wayland platform
    env = SDL_VIDEODRIVER,wayland          # SDL Wayland driver
    env = _JAVA_AWT_WM_NONREPARENTING,1    # Java AWT Wayland compatibility
    env = CLUTTER_BACKEND,wayland          # Clutter Wayland backend
    env = GDK_BACKEND,wayland,x11          # GTK Wayland with X11 fallback
  '';
}
