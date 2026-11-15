{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.development;
in
{
  config = mkIf (cfg.enable && cfg.nodejs) {
    environment.systemPackages =
      [
        pkgs.nodejs_24
        pkgs.pm2
      ];
  };
}
