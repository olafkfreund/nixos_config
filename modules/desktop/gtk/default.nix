{ pkgs, ... }: {
  # gdk-pixbuf is pulled in transitively by librsvg; listing both collides
  # on lib/gdk-pixbuf-2.0/.../loaders.cache.
  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    gnome-themes-extra
    shared-mime-info
    librsvg
    gtk3
    gtk4
    gsettings-desktop-schemas
  ];

  environment.variables = {
    GTK_PATH = "${pkgs.gtk3}/lib/gtk-3.0:${pkgs.gtk4}/lib/gtk-4.0";
    GDK_PIXBUF_MODULE_FILE = "${pkgs.librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache";
  };
}
