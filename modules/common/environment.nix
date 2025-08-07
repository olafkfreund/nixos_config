# modules/desktop/wayland/environment.nix
{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.wayland-environment;
in
{
  options.wayland-environment = {
    enable = mkEnableOption "Common Wayland environment variables";

    nvidia = mkOption {
      type = types.bool;
      default = false;
      description = "Enable NVIDIA-specific Wayland variables";
    };

    headless = mkOption {
      type = types.bool;
      default = false;
      description = "Enable headless mode for Wayland (useful for remote desktop)";
    };
  };

  config = mkIf cfg.enable {
    environment.sessionVariables =
      {
        # Common Wayland variables
        SDL_VIDEODRIVER = "wayland";
        QT_QPA_PLATFORM = "wayland";
        QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
        _JAVA_AWT_WM_NONREPARENTING = "1";
        MOZ_ENABLE_WAYLAND = "1";
        NIXOS_WAYLAND = "1";
        NIXOS_OZONE_WL = "1";
        ELECTRON_OZONE_PLATFORM_HINT = "wayland";

        # GTK settings
        GTK_THEME = mkDefault "Gruvbox-Dark-B-LB";
        GDK_BACKEND = "wayland,x11";

        # Qt additional settings
        QT_AUTO_SCREEN_SCALE_FACTOR = "1";
        QT_ENABLE_HIGHDPI_SCALING = "1";
      }
      // (mkIf cfg.nvidia {
        # NVIDIA-specific settings
        WLR_DRM_NO_ATOMIC = "1";
        WLR_NO_HARDWARE_CURSORS = "1";
        LIBVA_DRIVER_NAME = "nvidia";
        GBM_BACKEND = "nvidia-drm";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        EGL_PLATFORM = "wayland";
        MOZ_DISABLE_RDD_SANDBOX = "1";
      })
      // (mkIf cfg.headless {
        # Headless mode settings
        WLR_BACKENDS = "headless,libinput";
        WLR_LIBINPUT_NO_DEVICES = "1";
      });

    # Add common system packages for Wayland
    environment.systemPackages = with pkgs; [
      wl-clipboard
      wlr-randr
    ];
  };
}
