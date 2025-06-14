{
  config,
  lib,
  pkgs,
  ...
}: {
  options.custom.host = {
    name = lib.mkOption {
      type = lib.types.str;
      description = "The hostname of this system";
    };

    type = lib.mkOption {
      type = lib.types.enum ["workstation" "laptop" "server" "htpc"];
      description = "The type of host system";
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of users for this host";
    };

    hardwareProfile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Hardware profile name for this host";
    };
  };

  # No config section needed - these are just option declarations
}
