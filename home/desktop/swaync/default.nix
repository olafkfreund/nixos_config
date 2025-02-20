{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.desktop.swaync;
in {
  options.desktop.swaync = {
    enable = mkEnableOption {
      default = false;
      description = "Sway notification center";
    };
  };
  config = mkIf cfg.enable {
    services.swaync = {
      enable = true;
      package = pkgs.swaynotificationcenter;
    };
    xdg.configFile."swaync/style.css".source = ./style.css;
    xdg.configFile."swaync/config.json".source = ./config.json;
  };
}
