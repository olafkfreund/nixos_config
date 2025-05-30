{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.github.development;
in {
  options.github.development = {
    enable = mkEnableOption "Enable GitHub development environment";
    packages = mkOption {
      type = with types; listOf str;
      default = [];
      description = "Packages to install for GitHub development";
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages =
      [
        pkgs.act # actionlint
        pkgs.actionlint
        pkgs.action-validator
        pkgs.gitea-actions-runner
        pkgs.gh-copilot
        pkgs.gh-notify
        pkgs.ghfetch
        pkgs.gh-dash
        pkgs.gh-markdown-preview
        pkgs.github-cli
        pkgs.github-mcp-server
      ]
      ++ cfg.packages;
  };
}
