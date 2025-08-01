{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./chatgpt.nix
    ./gemini-cli.nix
    ./providers/default.nix
    ./analysis/default.nix
    ./memory-optimization.nix
    ./grafana-dashboards.nix
    ./prometheus-alerts.nix
    ./automated-remediation.nix
    ./storage-analysis.nix
    ./backup-strategy.nix
    ./storage-expansion.nix
    ./storage-migration.nix
    ./security-audit.nix
    ./system-validation.nix
    ./performance-optimization.nix
    ./production-dashboard.nix
    ./load-testing.nix
    ./alerting-system.nix
  ];

  environment.systemPackages = [
    pkgs.chatgpt-cli
    pkgs.rPackages.chatgpt
    pkgs.tgpt
    pkgs.gh-copilot
    pkgs.yai
    pkgs.shell-gpt
    pkgs.aichat
    pkgs.gorilla-cli
    # Temporarily disabled due to llama-index-core build failure (upstream nixpkgs issue)
    # pkgs.newelle
    # Temporarily disabled due to textual package test failures
    # pkgs.oterm
    pkgs.gpt-cli
    pkgs.chatmcp
    inputs.claude-desktop.packages.x86_64-linux.claude-desktop-with-fhs
  ];
}
