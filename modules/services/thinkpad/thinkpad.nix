{ self, config, pkgs, ... }: {

services.tp-auto-kbbl = {
  enable = false;
  };
services.thinkfan = {
  enable = true;
  };
services.fwupd = {
  enable = true;
  };
}
