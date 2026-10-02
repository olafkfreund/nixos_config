{ pkgs
, config
, lib
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.desktop.screenshots.omareel;
in
{
  options.desktop.screenshots.omareel = {
    enable = mkEnableOption "Omareel screen recorder";
  };
  config = mkIf cfg.enable {
    home.packages = [
      pkgs.customPkgs.omareel
    ];
  };
}
