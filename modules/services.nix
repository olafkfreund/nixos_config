{ self, config, pkgs, ... }: {

# Enable CUPS to print documents.
services.printing = {
  enable = true;
  };
services.tp-auto-kbbl = {
  enable = true;
  };
services.thinkfan = {
  enable = true;
  };
services.flatpak = {
  enable = true;
  };
# Enable touchpad support (enabled default in most desktopManager).
services.xserver.libinput.enable = true;
services.openssh = {
  enable = true;
  settings.X11Forwarding = true;
  };
}
