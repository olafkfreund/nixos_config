{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.streamdeck.enable;
in {
  config = mkIf cfg {
    programs.streamcontroller = {
      enable = true;
      package = pkgs.streamcontroller;
    };
  };
}
