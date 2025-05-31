{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.browsers.chrome;
in {
  options.browsers.chrome = {
    enable = mkEnableOption "Google Chrome";
  };

  config = mkIf cfg.enable {
    # Set environment variables for the user session
    home.sessionVariables = {
      # Set GTK theme
      GTK_THEME = "Adwaita";
      # Use system-provided pixbuf loaders to avoid conflicts
      GDK_PIXBUF_MODULE_FILE = "${pkgs.gdk-pixbuf}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache";
      # Set cursor theme
      XCURSOR_THEME = "Adwaita";
    };

    # Configure Chrome with proper Wayland support
    programs.chromium = {
      enable = true;
      package = pkgs.google-chrome;
      commandLineArgs = [
        # Wayland support
        "--enable-features=UseOzonePlatform,WaylandWindowDecorations"
        "--ozone-platform=wayland"
        "--enable-wayland-ime"

        # Performance and stability
        "--disable-dev-shm-usage"
        "--force-device-scale-factor=1"
        "--no-sandbox"

        # GTK and theming fixes
        "--gtk-version=4"
        "--force-dark-mode=false"

        # Hardware acceleration
        "--enable-hardware-acceleration"
        "--ignore-gpu-blocklist"

        # Wayland-specific fixes
        "--enable-features=VaapiVideoDecoder"
        "--disable-gpu-sandbox"

        # Fix registration errors
        "--disable-background-mode"
        "--disable-background-timer-throttling"

        # Reduce console noise
        "--disable-logging"
        "--silent"
        "--log-level=3"
      ];
    };
  };
}
