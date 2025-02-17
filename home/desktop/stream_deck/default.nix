{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.streamcontroller.enable;
in {
  config = mkIf cfg {
    programs.streamcontroller = {
      enable = true;
      package = pkgs.streamcontroller;
    };
  };
}
