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
  config = mkIf (cfg.enable && cfg.devshell) {
    environment.systemPackages =
      [
        pkgs.devbox
        pkgs.devenv
      ];
  };
}
