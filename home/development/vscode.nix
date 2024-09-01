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
    home.packages = with pkgs; [alejandra deadnix statix];

    programs.vscode.extensions = with pkgs; [
      vscode-extensions.bbenoist.nix
      vscode-extensions.kamadorueda.alejandra
    ];

    programs.vscode.userSettings."[nix]" = {
      "editor.defaultFormatter" = "kamadorueda.alejandra";
      "editor.formatOnSave" = true;
    };
    programs.vscode.userSettings = {
      "alejandra.program" = "alejandra";
    };
  };
}
