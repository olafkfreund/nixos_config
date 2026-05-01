{ config
, lib
, pkgs-unstable
, ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.editor.cursor;
in
{
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
