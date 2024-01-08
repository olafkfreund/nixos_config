{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}: {
hardware.bluetooth.enable = true;
hardware.bluetooth.powerOnBoot = true;
services.blueman.enable = true;
}
