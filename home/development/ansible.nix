{ pkgs, pkgs-stable, ... }: {
  home.packages = [
    pkgs.ansible
    pkgs.ansible-lint
    pkgs-stable.ansible-navigator
  ];
}
