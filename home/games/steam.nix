{ pkgs, ... }: {
  home.packages = with pkgs; [
    steam
    protonup-qt
    gamescope
    steam-rom-manager
    steamtinkerlaunch
    proton-caller
    protontricks
    steam-run
    lutris
  ];
}
