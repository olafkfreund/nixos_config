{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # nodePackages.neovim
    vimPlugins.nix-develop-nvim
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
    tmux-xpanes
    # mapscii
    tdf
    nb
    hugo
    # rPackages.rgr
    serie
    rainfrog
    netscanner
    atac
    ddgr
  ];
}
