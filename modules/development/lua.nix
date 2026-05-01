{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkOption mkIf mkEnableOption types;
  cfg = config.lua.development;
in
{
  options.lua.development = {
    enable = mkEnableOption "Enable Lua development environment";
    packages = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "Packages to install for Lua development";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages =
      [
        pkgs.lua
        pkgs.stylua
        pkgs.lua-language-server
      ]
      ++ cfg.packages;
  };
}
