{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = [
    pkgs.chatgpt-cli
    pkgs.rPackages.chatgpt
    pkgs.tgpt
    pkgs.github-copilot-cli
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
