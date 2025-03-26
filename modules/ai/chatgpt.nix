{pkgs, pkgs-unstable, ...}: {
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
  ];
}
