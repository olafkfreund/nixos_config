{ lib, config, pkgs, ... }: {

home.packages = [
  pkgs.chatgpt-cli
  pkgs.rPackages.chatgpt
  pkgs.tgpt
	pkgs.github-copilot-cli
  pkgs.yai
  pkgs.shell-gpt
  pkgs.aichat
  ];
}
