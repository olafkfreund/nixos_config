{ pkgs, ... }: {

  home.packages = with pkgs; [
  
    gnome-themes-extra
    libadwaita
    gnome.adwaita-icon-theme
    gsettings-desktop-schemas
    gnome-extension-manager
    gnome.gnome-themes-extra
    gnome.gnome-tweaks
    gnomeExtensions.gsconnect
    gnomeExtensions.user-themes
    gnomeExtensions.appindicator
    gimp
  ];
}