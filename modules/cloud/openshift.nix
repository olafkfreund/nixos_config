{ pkgs
, config
, lib
, ...
}:
with lib; let
  cfg = config.openshift.packages;
in
{
  options.openshift.packages = {
    enable = mkEnableOption "Enable OpenShift packages";
  };
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # aws
      ocm
      telepresence
      rhoas
      crc
    ];
  };
}
