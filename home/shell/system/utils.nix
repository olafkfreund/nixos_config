{ pkgs, config, ... }: {

  home.packages = with pkgs; [
      hyprpaper
      swaybg
      nodePackages.neovim
	    vimPlugins.nix-develop-nvim
	    github-copilot-cli
      figlet
      gum
  ];
}
