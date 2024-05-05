{ lib, config, pkgs, ... }: {

home.packages = with pkgs; [
  chatgpt-cli
  rPackages.chatgpt
  tgpt
	github-copilot-cli
  yai
  ];
}
