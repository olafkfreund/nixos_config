{ pkgs, ... }: {
  home.packages = with pkgs; [
    shellcheck
    shfmt
    ncurses
    cmakeCurses
    atac
    markdownlint-cli
  ];
}
