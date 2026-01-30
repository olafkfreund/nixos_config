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
    # GeForce NOW: Now using official NVIDIA Flatpak via modules.services.geforcenow
    # Enable with: modules.services.geforcenow.enable = true
  ];
}
