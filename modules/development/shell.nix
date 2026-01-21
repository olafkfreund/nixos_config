{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.shell.development;
in
{
  options.shell.development = {
    enable = mkEnableOption "Enable Shell development environment";
    packages = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "Packages to install for Shell development";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages =
      [
        pkgs.shellcheck
        pkgs.shfmt
        pkgs.yamllint
        pkgs.ncurses
        pkgs.cmakeCurses
        pkgs.upbound
        pkgs.crossplane-cli
        pkgs.just
        pkgs.atac
        pkgs.termshark
      ]
      ++ cfg.packages;
  };
}
