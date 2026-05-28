{ lib
, config
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption mkPackageOption;
  cfg = config.programs.aerion;
in
{
  options.programs.aerion = {
    enable = mkEnableOption "Aerion lightweight email client";
    package = mkPackageOption pkgs "aerion" { };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
