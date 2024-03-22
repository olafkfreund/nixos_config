{ self, config, pkgs, ... }: {
services.tp-auto-kbbl = {
  enable = true;
  };
services.thinkfan = {
  enable = true;
  };
services.fwupd = {
  enable = true;
  };
}
