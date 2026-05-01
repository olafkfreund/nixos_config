{ config
, lib
, pkgs-unstable
, ...
}:
let
  inherit (lib) mkOption mkIf mkEnableOption types;
  cfg = config.go.development;
in
{
  options.go.development = {
    enable = mkEnableOption "Enable Go development environment";
    packages = mkOption {
      type = with types; listOf str;
      default = [
      ];
      description = "Packages to install for Go development";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages =
      [
        pkgs-unstable.go
        pkgs-unstable.gopls
        pkgs-unstable.gore
        pkgs-unstable.go-task
        pkgs-unstable.timoni
      ]
      ++ cfg.packages;
  };
}
