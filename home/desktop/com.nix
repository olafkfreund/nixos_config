{ pkgs, ... }: {

home.packages = with pkgs; [
  slack
  teams-for-linux
  thunderbird
  obsidian
  zathura
  dbeaver
  postgresql
  ];
}
