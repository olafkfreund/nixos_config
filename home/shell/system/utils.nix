{ pkgs, ... }: {

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
    openapi-tui
    fast-ssh
    lazycli
    systemctl-tui
    bluetuith
    fzf-obc
    youtube-tui
    # ytfzf
    tmux-xpanes
    mapscii
    tdf
    nb
  ];
}
