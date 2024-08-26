{pkgs, ...}: {
  services = {
    dbus.packages = with pkgs; [
      gcr
      gnome.gnome-settings-daemon
    ];

    gnome = {
      gnome-keyring.enable = true;
      core-utilities.enable = false;
      games.enable = false;
      gnome-online-accounts.enable = true;
    };
    gvfs.enable = true;
  };
}
