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
    # home.sessionVariables = {
    #   # Set GTK theme
    #   GTK_THEME = "Adwaita";
    #   # Use system-provided pixbuf loaders to avoid conflicts
    #   GDK_PIXBUF_MODULE_FILE = "${pkgs.gdk-pixbuf}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache";
    #   # Set cursor theme
    #   XCURSOR_THEME = "Adwaita";
    #   XDG_DATA_DIRS = "${pkgs.adwaita-icon-theme}/share:${pkgs.hicolor-icon-theme}/share:${pkgs.gtk3}/share:${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:${pkgs.gtk4}/share";
    # };

    # Configure Chrome with proper Wayland support (secure configuration)
    programs.chromium = {
      enable = true;
      package = pkgs.google-chrome;
      commandLineArgs = [
        # Native Wayland support (VizDisplayCompositor disabled for Hyprland compatibility)
        "--enable-features=UseOzonePlatform"
        "--ozone-platform=wayland"

        # CRITICAL FIX: Disable VizDisplayCompositor to fix page loading on Hyprland
        "--disable-features=VizDisplayCompositor"
        
        # Fix zygote/sandbox error by disabling problematic sandbox features
        "--disable-dev-shm-usage"
        "--disable-gpu-sandbox"
        "--disable-software-rasterizer"
        
        # Memory and process management
        "--memory-pressure-off"
        "--max_old_space_size=4096"
      ];
    };
  };
}
