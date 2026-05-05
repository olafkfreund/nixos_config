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

  # Trim GNOME defaults that survive `core-apps.enable = false` via transitive
  # deps. The packages we *do* want (gnome-calendar, gnome-contacts, etc.) are
  # listed in environment.systemPackages below.
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    epiphany
    geary
    gnome-music
    gnome-photos
    yelp
    cheese
  ];

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
    gnomeExtensions.user-themes
    gnomeExtensions.appindicator
    gimp
    cameractrls-gtk4
  ];
}
