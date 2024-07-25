{ pkgs, ... }: {

  home.packages = with pkgs; [
    #direnv #direnv
    ripgrep #grep replacement
    #fzf #fuzzy finder
    aria2 #download manager
    glow #markdown preview
    eza #replace ls
    #bat #cat replacement
    topgrade #update all
    nerdfonts #fonts
    wtf #terminal dashboard
    starship #prompt replacement
    #neofetch #os printout
    fastfetch # like neofetch only faster
    #zoxide #A fast cd command that learns your habits
    less #
    #zellij #terminal multiplexer
    navi #cheatsheet
    tokei #code stats
    pass #password manager
    gnupg #gpg
    #lsix #image preview
    feh #image preview
    jmespath #json parser
    jq #json parser
    pandoc #markdown to pdf
    atuin #tui history manager
    cheat #cheatsheet
    #yazi #file manager
    ffmpegthumbnailer #thumbnailer
    macchina #file manager
    slides #markdown presentation
    tldr #cheatsheet
    khal #calendar
    newsboat #rss reader
    buku #bookmark manager
    desktop-file-utils #desktop file manager
    xdg-utils #desktop file manager
    xdg-user-dirs #desktop file manager
  ];
}

