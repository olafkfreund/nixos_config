{ config
, lib
, pkgs-unstable
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.editors;
in
{
  config = mkIf (cfg.enable && cfg.cursor) {
    home.packages = with pkgs-unstable; [
      code-cursor
    ];
  };
}
