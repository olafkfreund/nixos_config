{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: 
with lib; let
  cfg = config.swaylock;
in {
  options.swaylock = {
    enable = mkEnableOption {
      default = false;
      description = "swaylock";
    };
  };
  config = mkIf cfg.enable {
    programs.swaylock = {
      enable = true;
      settings = {
        font-size = 24;
        indicator-idle-visible = false;
        indicator-radius = 100;
        show-failed-attempts = true;
      };
    };
};
}
