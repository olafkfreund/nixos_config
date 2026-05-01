{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.google.packages;
in
{
  options.google.packages = {
    enable = mkEnableOption "Enable Google packages";
  };
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      google-cloud-sdk
    ];
  };
}
