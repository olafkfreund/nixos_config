{pkgs, ...}: {
  
  services = {
    # needed for GNOME services outside of GNOME Desktop
    dbus.packages = with pkgs; [
      gcr
      gnome.gnome-settings-daemon
    ];

    gnome.gnome-keyring.enable = true;

    gvfs.enable = true;
  };

  home-manager.users.olafkfreund = {
  dconf = {
    enable = true;
    # settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
    };
  };
}
