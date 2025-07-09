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
    pkgs.oterm
    pkgs.gpt-cli
    pkgs.chatmcp
    inputs.claude-desktop.packages.x86_64-linux.claude-desktop
    # pkgs.claude-code
  ];
}
