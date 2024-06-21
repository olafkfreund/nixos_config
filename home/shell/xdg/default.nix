{ pkgs, ... }: {
  home.packages = with pkgs; [
    xdg-utils
    xdg-user-dirs
    xdg-launch
  ];
}
