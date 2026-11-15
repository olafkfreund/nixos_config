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
  config = mkIf (cfg.enable && cfg.remotedesktop) {
    home.packages = [
      pkgs.remmina
      pkgs.freerdp
    ];
  };
}
