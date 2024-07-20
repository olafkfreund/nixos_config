{ pkgs, ... }: {

home.packages = with pkgs; [
    shellcheck
    shfmt
    ncurses
    cmakeCurses
    upbound
    crossplane-cli
    just
  ];
}
