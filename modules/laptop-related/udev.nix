{ pkgs, ... }:

{
  #---------------------------------------------------------------------
  # Dynamic device management. udev is responsible for device detection, 
  # device node creation, and managing device events.
  #---------------------------------------------------------------------
  services = {
    udev = {
      enable = true;
      packages = with pkgs; [ gnome.gnome-settings-daemon ];
    };

  };
}
