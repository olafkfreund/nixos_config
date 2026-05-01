{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkOption mkIf mkEnableOption types;
  cfg = config.java.development;
in
{
  options.java.development = {
    enable = mkEnableOption "Enable Java development environment";
    packages = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "Packages to install for Java development";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages =
      [
        pkgs.zulu25
        pkgs.gradle
        pkgs.maven
        # pkgs.jetbrains.idea-community-bin
      ]
      ++ cfg.packages;
  };
}
