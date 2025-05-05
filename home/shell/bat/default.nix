{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.cli.bat;
in {
  options.cli.bat = {
    enable = mkEnableOption {
      default = true;
      description = "bat";
    };
  };
  config = mkIf cfg.enable {
    programs.bat = {
      enable = true;
      config = {
        # theme = "gruvbox-dark";
        style = "numbers,changes";
        pager = "less -FR";
      };
      extraPackages = with pkgs.bat-extras; [
        batman
        batpipe
        batgrep
      ];
    };
  };
}
