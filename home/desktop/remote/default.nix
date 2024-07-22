{ pkgs, ... }: {
  home.packages = [
    pkgs.waypipe
    pkgs.wayvnc
  ];
}
