{
  lib,
  config,
  inputs,
  pkgs,
  ...
}: with lib; let
  cfg = config.programs.slack;
in {
  options.programs.slack = {
    enable = mkEnableOption {
      default = false; 
      description = "Slack";
    };
  };
  config = mkIf cfg.enable {
    xdg.mimeApps.defaultApplications = {
      "x-scheme-handler/slack" = "slack.desktop";
    };
    home.packages = with pkgs; [ slack ];
  };
}
