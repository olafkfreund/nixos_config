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
        "--enable-features=UseOzonePlatform"
        "--ozone-platform=wayland"
        "--enable-wayland-ime"
        "--disable-dev-shm-usage"
        "--force-device-scale-factor=1"
        # Additional flags to help with GTK issues
        "--gtk-version=4"
        "--no-sandbox"
      ];
    };
  };
}
