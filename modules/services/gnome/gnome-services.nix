{ pkgs, ... }: {
  services = {
    dbus.packages = with pkgs; [
      gcr
      gnome-settings-daemon
    ];

    gnome = {
      gnome-keyring.enable = true;
      core-apps.enable = false;
      games.enable = false;
      gnome-online-accounts.enable = true;
    };
    gvfs.enable = true;
  };
  environment.systemPackages = with pkgs; [
    gnome-themes-extra
    nautilus
    nautilus-open-any-terminal
    libadwaita
    adwaita-icon-theme
    gsettings-desktop-schemas
    gnome-extension-manager
    gnome-calendar
    gnome-contacts
    gnome-weather
    gnome-online-accounts
    gnome-tweaks
    gnome-control-center
    gnome-boxes
    gnomeExtensions.gtile
    gnomeExtensions.gmeet
    gnomeExtensions.user-themes
    gnomeExtensions.appindicator
    gimp
    cameractrls
    cameractrls-gtk4
    # alpaca  # Disabled due to Python 3.13 compatibility issues with mercantile dependency
  ];
}
