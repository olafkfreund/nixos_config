{ config
, lib
, pkgs
, ...
}:
with lib; let
  cfg = config.browsers.opera;
in
{
  options.browsers.opera = {
    enable = mkEnableOption {
      default = false;
      description = "Opera browser";
    };
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      opera
    ];
  };
}
