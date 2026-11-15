{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.browsers;
in
{
  config = mkIf (cfg.enable && cfg.opera) {
    home.packages = with pkgs; [
      opera
    ];
  };
}
