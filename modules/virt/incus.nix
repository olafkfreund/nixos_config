{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.virtualization;
in
{
  config = mkIf (cfg.enable && cfg.incus) {
    virtualisation = {
      incus = {
        package = pkgs.incus;
        enable = true;
      };
    };
    virtualisation.incus.ui.enable = true;
  };
}
