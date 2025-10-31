{ pkgs, ... }: {
  home.packages = with pkgs; [
    steam
    protonup-qt
    gamescope
    steam-rom-manager
    steamtinkerlaunch
    # proton-caller removed - unmaintained package
    protontricks
    steam-run
    lutris
    gfn-electron
  ];
}
