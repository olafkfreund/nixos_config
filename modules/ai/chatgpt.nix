{
  pkgs,
  inputs,
  pkgs-unstable,
  ...
}: {
  environment.systemPackages = [
    pkgs-unstable.chatgpt-cli
    pkgs.rPackages.chatgpt
    pkgs-unstable.tgpt
    pkgs.github-copilot-cli
    pkgs-unstable.yai
    pkgs-unstable.shell-gpt
    pkgs-unstable.aichat
    pkgs-unstable.gorilla-cli
    pkgs-unstable.oterm
    pkgs-unstable.gpt-cli
    pkgs-unstable.chatmcp
    inputs.claude-desktop.packages.x86_64-linux.claude-desktop
  ];
}
