{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
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
      libreoffice-fresh
    ];
  };
}
