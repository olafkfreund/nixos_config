{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.cloud-tools.packages;
in
{
  options.cloud-tools.packages = {
    enable = mkEnableOption "Enable cloud tools";
  };
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      teller
      yq-go
      ytt
    ];
  };
}
