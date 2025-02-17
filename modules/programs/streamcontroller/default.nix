{
  self,
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.streamcontroller;
in {
  options.programs.streamcontroller = {
    enable = mkEnableOption {
      description = "Enable Streamcontroller";
      default = false;
    };
  };
  config = mkIf cfg.enable {
    programs.streamcontroller = {
      enable = true;
      package = pkgs.streamcontroller;
    };
  };
}
