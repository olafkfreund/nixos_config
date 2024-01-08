{ self, config, pkgs, ... }: {

services.openssh = {
  enable = true;
  settings.X11Forwarding = true;
  };
}
