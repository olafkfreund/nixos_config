{ config, lib, inputs, ... }:
let
  cfg = config.features.craftapps;
  names = builtins.attrNames (lib.importJSON "${inputs.nix-craftapps}/apps.json");
in
{
  imports = [ inputs.nix-craftapps.nixosModules.default ];

  options.features.craftapps = {
    enable = lib.mkEnableOption "the ArtCraft Crafting Apps";
    apps = lib.genAttrs names (name: lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include ${name} (false excludes it).";
    });
  };

  config = lib.mkIf cfg.enable {
    programs.craftapps = {
      enable = true;
      apps = lib.mapAttrs (_: enable: { inherit enable; }) cfg.apps;
    };
  };
}
