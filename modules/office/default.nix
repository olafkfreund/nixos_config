{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.programs.office;
in
{
  options.programs.office = {
    enable = mkEnableOption {
      default = false;
      description = "Office suite";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      freeoffice
      onlyoffice-desktopeditors
    ];
  };
}
