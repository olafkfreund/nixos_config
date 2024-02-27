{ pkgs, ...}: {
  home.packages = with pkgs; [
    brave # Brave browser
  ];
}
