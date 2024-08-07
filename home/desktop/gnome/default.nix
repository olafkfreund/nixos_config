{ pkgs, ... }: {

  home.packages = with pkgs; [
  
    gnome-themes-extra
    libadwaita
    adwaita-icon-theme
    gsettings-desktop-schemas
    gnome-extension-manager
    gnome-themes-extra
    gnome.gnome-control-center
    gnomeExtensions.gtile
    gnomeExtensions.gmeet
    gnomeExtensions.user-themes
    gnomeExtensions.appindicator
    gimp
  ];
}
