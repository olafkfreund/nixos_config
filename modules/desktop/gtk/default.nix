{ pkgs, ... }: {
  # Install GTK and theming packages at system level to avoid conflicts
  environment.systemPackages = with pkgs; [
    # GTK and theming dependencies
    adwaita-icon-theme
    gnome-themes-extra
    shared-mime-info
    gdk-pixbuf
    librsvg
    # Additional packages for proper Chrome integration
    gtk3
    gtk4
    gsettings-desktop-schemas
  ];

  # Configure environment variables at system level
  environment.variables = {
    # Ensure consistent GTK configuration
    GTK_PATH = "${pkgs.gtk3}/lib/gtk-3.0:${pkgs.gtk4}/lib/gtk-4.0";
    GDK_PIXBUF_MODULE_FILE = "${pkgs.librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache";
  };
}
