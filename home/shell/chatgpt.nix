{ lib, config, pkgs, ... }: {

home.packages = with pkgs; [
  shell_gpt
  chatgpt-cli
  rPackages.chatgpt
  tgpt
	github-copilot-cli
  yai
  ];
}
