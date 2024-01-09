{ pkgs, ... }: {

  imports = [
    pkgs.ansible_2_14
    pkgs.ansible-lint
  ];

  home.packages = with pkgs; [
    ansible_2_14
    ansible-lint
  ];
}
