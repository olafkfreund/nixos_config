{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nodejs.development;
in {
  options.nodejs.development = {
    enable = mkEnableOption "Enable Node development environment";
    packages = mkOption {
      type = with types; listOf str;
      default = [];
      description = "Packages to install for Node development";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.nodejs_22
    ] ++ cfg.packages;
  };
}
