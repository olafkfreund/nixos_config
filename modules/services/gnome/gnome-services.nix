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
  # deps. The user-facing apps (nautilus, gnome-calendar, gnome-contacts,
  # gnome-weather, gnome-tweaks) are owned by home/desktop/gnome/, not here —
  # see the note on environment.systemPackages below.
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    epiphany
    geary
    gnome-music
    gnome-photos
    yelp
    cheese
  ];

  # System-level only: themes, schemas, settings, and apps with no per-user
  # config. GNOME *applications* belong to home/desktop/gnome/, which reaches
  # p620 and razer via Users/olafkfreund/profile.nix.
  #
  # Declaring an app in both layers puts its .service file in both
  # /run/current-system/sw and /etc/profiles/per-user/$USER, and dbus-broker
  # logs "Ignoring duplicate name" at priority err for each one on every
  # session start — ~5000 lines a boot on p620 before this was split. It also
  # dragged nautilus, gnome-boxes, gimp and darktable into headless p510's
  # closure, since this module is imported unconditionally via modules/core.nix.
  environment.systemPackages = with pkgs; [
    gnome-themes-extra
    libadwaita
    adwaita-icon-theme
    gsettings-desktop-schemas
    gnome-online-accounts
    gnome-control-center
    gnome-boxes
    gnomeExtensions.user-themes
    gnomeExtensions.appindicator
    gimp
    krita # Qt-based image editor / GIMP alternative
    darktable # RAW photo workflow (Lightroom-like)
    cameractrls-gtk4
  ];
}
