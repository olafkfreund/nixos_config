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
    # lutris REMOVED: depends on moddb which has slow pyrate-limiter dependency (25+ min test phase)
    # Alternative: Install Lutris as flatpak or override to skip tests
    # gfn-electron REMOVED: Abandoned upstream and removed from nixpkgs
    # Alternative: Use GeForce NOW via web browser (works great in Chrome/Chromium)
  ];
}
