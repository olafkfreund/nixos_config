{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: 
with lib; let 
  cfg = config.editor.vscode;
in {
  options.editor.vscode = {
    enable = mkEnableOption {
      default = false;
      description = "vscode";
    };
  };
  config = mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      enableExtensionUpdateCheck = true;
      package = pkgs.vscode;
    };
  };
}
