{ pkgs, ... }: {
home.packages = with pkgs; [
  steam
  protonup-qt
  gamescope
  ];
}
