{pkgs, ...}: {
  environment.systemPackages = [
    pkgs.chatgpt-cli
    pkgs.rPackages.chatgpt
    pkgs.tgpt
    pkgs.github-copilot-cli
    pkgs.yai
    pkgs.shell-gpt
    pkgs.aichat
    pkgs.gorilla-cli
  ];
}
