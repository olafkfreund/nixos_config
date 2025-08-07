{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.cargo.development;
in
{
  options.cargo.development = {
    enable = mkEnableOption "Enable Cargo development environment";
    packages = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "Packages to install for Cargo development";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages =
      [
        pkgs.cargo
        pkgs.rust-analyzer
        pkgs.cargo-ui
        pkgs.cargo-update
        pkgs.slumber
        pkgs.openapi-tui
        pkgs.clipse
        pkgs.systemctl-tui
        pkgs.rustfmt
        pkgs.rustc
      ]
      ++ cfg.packages;
  };
}
