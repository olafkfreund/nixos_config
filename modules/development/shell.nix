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
  config = mkIf (cfg.enable && cfg.shell) {
    environment.systemPackages =
      [
        pkgs.shellcheck
        pkgs.shfmt
        pkgs.yamllint
        pkgs.ncurses
        pkgs.cmakeCurses
        pkgs.just
        pkgs.atac
      ];
  };
}
