{ pkgs, ... }: {

  home.packages = with pkgs; [
    ripgrep #grep replacement
    aria2 #download manager
    glow #markdown preview
    eza #replace ls
    topgrade #update all
    nerdfonts #fonts
    wtf #terminal dashboard
    fastfetch # like neofetch only faster
    less #
    navi #cheatsheet
    tokei #code stats
    pass #password manager
    gnupg #gpg
    feh #image preview
    jmespath #json parser
    jq #json parser
    pandoc #markdown to pdf
    atuin #tui history manager
    cheat #cheatsheet
    ffmpegthumbnailer #thumbnailer
    macchina #file manager
    slides #markdown presentation
    tldr #cheatsheet
    khal #calendar
    newsboat #rss reader
    buku #bookmark manager
  ];
}

