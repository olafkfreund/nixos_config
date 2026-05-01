{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkOption mkIf mkEnableOption types;
  cfg = config.devshell.development;
in
{
  options.devshell.development = {
    enable = mkEnableOption "Enable DevShell development environment";
    packages = mkOption {
      type = with types; listOf package;
      default = [ ];
      description = "Packages to install for DevShell development";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages =
      [
        pkgs.devbox
        pkgs.devenv
      ]
      ++ cfg.packages;
  };
}
