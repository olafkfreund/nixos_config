{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkOption mkIf mkEnableOption types;
  cfg = config.nodejs.development;
in
{
  options.nodejs.development = {
    enable = mkEnableOption "Enable Node development environment";
    packages = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "Packages to install for Node development";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages =
      [
        pkgs.nodejs_24
        pkgs.pm2
      ]
      ++ cfg.packages;
  };
}
