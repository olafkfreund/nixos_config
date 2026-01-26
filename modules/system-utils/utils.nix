{ pkgs, ... }: {
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
    # openapi-tui  # Temporarily disabled - build fails with GCC 15 (onig_sys compatibility issue)
    fast-ssh
    lazycli
    systemctl-tui
    bluetuith
    fzf-obc
    # youtube-tui
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
    rusti-cal
    lazyjournal
    lazysql
    clamav
    parallel
    yq-go
    # nchat
  ];
}
