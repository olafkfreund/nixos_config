{ pkgs, config, ... }: {

  home.packages = with pkgs; [
      ulauncher
      nodePackages.neovim
	    vimPlugins.nix-develop-nvim
	    github-copilot-cli
      figlet
  ];
}
