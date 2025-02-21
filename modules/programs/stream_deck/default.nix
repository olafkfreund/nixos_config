{
  self,
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
with lib; let
  cfg = config.program.streamcontroller;
in {
  options.program.streamcontroller = {
    enable = mkEnableOption {
      description = "Enable Streamcontroller";
      default = false;
    };
  };
  config = mkIf cfg.enable {
    programs.streamcontroller = {
      enable = true;
      package = pkgs-unstable.streamcontroller;
    };
  };
}
