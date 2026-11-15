{ lib
, config
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkPackageOption;
  cfg = config.features.desktop;
in
{
  options.features.desktop.aerionPackage = mkPackageOption pkgs "aerion" { };

  config = mkIf (cfg.enable && cfg.aerion) {
    home.packages = [ cfg.aerionPackage ];
  };
}
