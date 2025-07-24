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
        "--enable-features=UseOzonePlatform,WaylandWindowDecorations,VaapiVideoDecoder"
        "--ozone-platform=wayland"
        
        # Wayland input and display
        "--enable-wayland-ime"
        # CRITICAL FIX: Disable VizDisplayCompositor to fix page loading on Hyprland
        "--disable-features=VizDisplayCompositor"
        
        # Secure memory management
        "--disable-dev-shm-usage"
        "--memory-pressure-off"
        
        # Graphics acceleration (secure)
        "--use-gl=desktop"
        "--enable-gpu-rasterization"
        "--enable-zero-copy"
        
        # Process management
        "--process-per-site"
        "--max_old_space_size=4096"
      ];
    };
  };
}
