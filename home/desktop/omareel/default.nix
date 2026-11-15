{ pkgs
, config
, lib
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.desktop;
in
{
  config = mkIf (cfg.enable && cfg.omareel) {
    home.packages = [
      pkgs.customPkgs.omareel
    ];
  };
}
