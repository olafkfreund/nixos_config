{ pkgs, ... }: {
  services = {
    udev = {
      enable = true;
      packages = with pkgs; [ gnome-settings-daemon ];
    };
  };
}
