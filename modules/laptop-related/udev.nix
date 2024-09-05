{pkgs, ...}: {
  services = {
    udev = {
      enable = true;
      packages = with pkgs; [gnome.gnome-settings-daemon];
    };
  };
}
