{ config, lib, pkgs, ... }:
# ddcutil — control external monitors over DDC/CI (brightness, contrast, input
# source) from software, no on-screen-display buttons needed. Enables the I2C
# subsystem and grants normal users access to /dev/i2c-* via the `i2c` group.
let
  inherit (lib) mkEnableOption mkIf filterAttrs;
  cfg = config.modules.hardware.ddcutil;
in
{
  options.modules.hardware.ddcutil.enable =
    mkEnableOption "ddcutil DDC/CI control of external monitors (brightness/contrast/input over I2C)";

  config = mkIf cfg.enable {
    # Loads the i2c-dev kernel module and installs udev rules giving the `i2c`
    # group read/write on /dev/i2c-*.
    hardware.i2c.enable = true;

    environment.systemPackages = [ pkgs.ddcutil ];

    # Put every normal user in the i2c group so `ddcutil` works without sudo.
    users.groups.i2c.members =
      builtins.attrNames (filterAttrs (_: u: u.isNormalUser) config.users.users);
  };
}
