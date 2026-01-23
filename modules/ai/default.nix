{ config
, lib
, pkgs
, ...
}:
with lib;
let
  cfg = config.features.ai;
in
{
  imports = [
    ./chatgpt.nix
    ./gemini-cli.nix
    ./providers/default.nix
    ./mcp-servers.nix
    # Non-functional AI modules removed - monitoring handled by Prometheus/Grafana on DEX5550
  ];

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.chatgpt-cli
      pkgs.rPackages.chatgpt
      pkgs.tgpt
      # pkgs.gh-copilot REMOVED - deprecated and archived upstream
      pkgs.yai
      # pkgs.shell-gpt REMOVED due to dependency conflict with openai>=2.0.0
      # aichat REMOVED due to extremely slow pyrate-limiter build dependency (2+ hours)
      pkgs.gorilla-cli
      # Temporarily disabled due to llama-index-core build failure (upstream nixpkgs issue)
      # pkgs.newelle
      # Temporarily disabled due to textual package test failures
      # pkgs.oterm
      pkgs.gpt-cli
      pkgs.chatmcp
    ] ++ optionals cfg.claude-desktop [ pkgs.customPkgs.claude-desktop ];
  };
}
