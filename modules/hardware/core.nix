{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.custom.hardware;
in {
  options.custom.hardware = lib.recursiveUpdate (import ../../lib/hardware.nix {inherit lib;}).hardwareOptions {
    profile = lib.mkOption {
      type = lib.types.str;
      description = "Hardware profile name";
    };
  };

  config = {
    # This is a base hardware module that defines the option structure
    # Actual hardware configuration is done in profile-specific modules
  };
}
