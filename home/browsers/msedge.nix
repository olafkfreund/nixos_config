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
  config = mkIf (cfg.enable && cfg.edge) {
    home.packages = with pkgs; [
      microsoft-edge
      # microsoft-edge-dev
    ];
  };
}
