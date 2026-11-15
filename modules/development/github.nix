{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.development;
in
{
  config = mkIf (cfg.enable && cfg.github) {
    environment.systemPackages =
      [
        pkgs.act # actionlint
        pkgs.actionlint
        pkgs.action-validator
        pkgs.gitea-actions-runner
        # pkgs.gh-copilot REMOVED - deprecated and archived upstream
        pkgs.gh-notify
        pkgs.ghfetch
        pkgs.gh-dash
        pkgs.gh-markdown-preview
        pkgs.github-cli
        pkgs.github-mcp-server
      ];
  };
}
