{ pkgs, ... }: {

home.packages = with pkgs; [
    nodePackages.bash-language-server
    shellcheck
    shfmt
    ncurses
    cmakeCurses
    upbound
    crossplane-cli
  ];
}
