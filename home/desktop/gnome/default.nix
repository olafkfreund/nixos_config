{ pkgs, ... }: {

  home.packages = with pkgs; [
    gnome-themes-extra
    nautilus
    nautilus-open-any-terminal
    libadwaita
    adwaita-icon-theme
    gsettings-desktop-schemas
    gnome-extension-manager
    gnome-themes-extra
    gnome-tweaks
    gnome.gnome-control-center
    gnomeExtensions.gtile
    gnomeExtensions.gmeet
    gnomeExtensions.user-themes
    gnomeExtensions.appindicator
    gimp
    cameractrls
    cameractrls-gtk4
    # alpaca
  ];
}
