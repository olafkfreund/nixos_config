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
<<<<<<< HEAD
      openapi-tui
      fast-ssh
      lazycli
      systemctl-tui
      bluetuith
=======
>>>>>>> 6f826e2188d86f7d0c76929d56e6cedb6863fd9d
  ];
}
