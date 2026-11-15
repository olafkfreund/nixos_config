{ config
, lib
, pkgs-unstable
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.development;
in
{
  config = mkIf (cfg.enable && cfg.go) {
    environment.systemPackages =
      [
        pkgs-unstable.go
        pkgs-unstable.gopls
        pkgs-unstable.gore
        pkgs-unstable.go-task
      ];
  };
}
