{ pkgs, ... }: {

home.packages = with pkgs; [
  slack
  teams-for-linux
  thunderbird
  betterbird
  obsidian
  zathura
  dbeaver
  postgresql
  slack-term
  caprine-bin
  element-desktop
  ];
}
