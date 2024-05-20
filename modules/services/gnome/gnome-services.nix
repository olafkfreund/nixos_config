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
<<<<<<< HEAD
    # settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
=======
    settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
>>>>>>> 6f826e2188d86f7d0c76929d56e6cedb6863fd9d
    };
  };
}
