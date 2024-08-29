{
  pkgs,
  self,
  config,
  lib,
  ...
}: 
with lib; let 
  cfg = config.desktop.screenshots.flameshot;
in {
  options.desktop.screenshots.flameshot = {
    enable = mkEnableOption {
      default = false;
      description = "Enable FlameShot screenshots";
     };
  };
  config = mkIf cfg.enable {
    services.flameshot = {
      enable = true;
      package = pkgs.flameshot.override {enableWlrSupport = true;};
    };
  };
}
