{
  config,
  lib,
  ...
}: {
  # Not working yet.
  # This is a NixOS module for Nixcord, a Discord client based on Vencord.
  # Only apply this configuration if the nixcord module is available
  options.programs.nixcord = with lib;
    mkOption {
      default = {};
      description = "Stub option to prevent errors when nixcord module is not available";
      type = types.attrsOf types.anything;
    };

  config = lib.mkDefault {
    # Empty configuration
  };
}
