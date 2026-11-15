{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.cli;
in
{
  config = mkIf (cfg.enable && cfg.markdown) {
    home.packages = with pkgs; [
      mdr
      slippy
      md-tui
    ];
  };
}
