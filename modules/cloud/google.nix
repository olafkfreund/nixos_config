{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.google.packages;
in {
  options.google.packages = {
    enable = mkEnableOption "Enable Google packages";
  };
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      google-cloud-sdk
    ];
  };
}
