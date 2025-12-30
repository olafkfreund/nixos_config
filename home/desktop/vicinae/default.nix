{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.desktop.vicinae;
in
{
  options.desktop.vicinae = {
    enable = mkEnableOption {
      default = false;
      description = "Vicinae spatial file manager with grid layout";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.vicinae ];
  };
}
