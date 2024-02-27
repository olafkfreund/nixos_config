{ self, config, pkgs, ... }: {

environment.sessionVariables = {
    WLR_DRM_NO_ATOMIC = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
    LIBVA_DRIVER_NAME = "nvidia";
    MOZ_DISABLE_RDD_SANDBOX = "1";
    EGL_PLATFORM = "wayland";
    MOZ_ENABLE_WAYLAND = "1";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    CORDA_ARTIFACTORY_USERNAME = "olaf.freund@r3.com";
    CORDA_ARTIFACTORY_PASSWORD = "AKCpBrw56m6sceapUZ2abMA6ZA2CH7MxNDbYgMYwmJTdG4jLfhLFjXVu2qcT8jFP7rEcXjdYM";
    };
}
