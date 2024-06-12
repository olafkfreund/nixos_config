{ pkgs, ... }: {

  home.packages = with pkgs; [
  
    gnome-themes-extra
    libadwaita
    gnome.adwaita-icon-theme
    gsettings-desktop-schemas
    gnome-extension-manager
    gnome.gnome-themes-extra
    gnome.gnome-tweaks
    gnome.gnome-control-center
    # gnomeExtensions.gsconnect
    gnomeExtensions.gtile
    gnomeExtensions.gmeet
    gnomeExtensions.user-themes
    gnomeExtensions.appindicator
    gimp
  ];
}
