{ pkgs, ... }: {
  home.packages = with pkgs; [
    ansible
    ansible-lint
    ansible-navigator
  ];
}
