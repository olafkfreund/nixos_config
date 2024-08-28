{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.go.development;
in {
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
    environment.systemPackages = [
      pkgs.go
      pkgs.gopls
      pkgs.gore
      pkgs.go-task
      pkgs.timoni
    ] ++ cfg.packages;
  };
}
