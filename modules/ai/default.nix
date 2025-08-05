{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./chatgpt.nix
    ./gemini-cli.nix
    ./providers/default.nix
    # ./analysis/default.nix  # Removed - was non-functional
    ./memory-optimization.nix
    ./grafana-dashboards.nix
    ./prometheus-alerts.nix
    ./automated-remediation.nix
    # ./storage-analysis.nix  # Removed - no meaningful analysis output
    # ./backup-strategy.nix  # Removed - no actual backups being created
    # ./storage-expansion.nix  # Removed - no expansion planning functionality
    # ./storage-migration.nix  # Removed - no migration functionality
    # ./security-audit.nix  # Removed - no actual audits performed
    # ./system-validation.nix  # Removed - no validation functionality
    # ./performance-optimization.nix  # Removed - no actual optimizations applied
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
