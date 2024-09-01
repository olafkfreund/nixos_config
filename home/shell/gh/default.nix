{
  pkgs,
  self,
  config,
  lib,
  ...
}: 
with lib; let 
  cfg = config.cli.versioncontrol.gh;
in {
  options.cli.versioncontrol.gh = {
    enable = mkEnableOption {
      default = false;
      description = "Enable GH cli";
     };
  };
  config = mkIf cfg.enable {
    programs.gh = {
      enable = true;
      extensions = with pkgs; [
        gh-dash
        gh-markdown-preview
        gh-notify
        github-copilot-cli # github copilot cli
        github-desktop # github desktop
        gh # github cli
        octofetch # github repository summary on your terminal
        lazygit
      ];
    };
  };
}
