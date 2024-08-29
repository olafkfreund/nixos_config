{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: 
with lib; let
  cfg = config.editor.cursor;
in {
  options.editor.cursor = {
    enable = mkEnableOption {
      default = false;
      description = "Enable Cursor AppImage";
    };
  };
  config = mkIf cfg.enable {
    home.packages = [
      (pkgs.writeShellScriptBin "cursor" ''
        cursor_app="$(find ~/Downloads/Apps/ -maxdepth 1 -name 'cursor*.AppImage' | sort | tail -n 1)"
        if [[ -f "$cursor_app" ]]; then
            appimage-run "$cursor_app" "$@"
        else
            echo "Cursor AppImage not found or not executable in ~/Downloads/Apps."
            exit 1
        fi
      '')
    ];
  };
}
