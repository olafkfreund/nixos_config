{ pkgs, config, ... }: {

  home.packages = with pkgs; [
            
      nodePackages.neovim
	    vimPlugins.nix-develop-nvim
	    # github-copilot-cli
      figlet
      gum
      mpv
      sox
      yad
      appimage-run
      fftw
      iniparser
  ];
}
