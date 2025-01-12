{
  inputs,
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
with lib; let
  cfg = config.editor.cursor;
in {
  options.editor.cursor = {
    enable = mkEnableOption {
      default = false;
      description = "Enable Cursor AI editor";
    };
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs-unstable; [
      code-cursor
    ];
  };
}
