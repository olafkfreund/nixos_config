{pkgs, ...}: {
  imports = [
    # New modular desktop structure
    ./core.nix
    ./hyprland.nix
    ./audio.nix

    # Existing modules for compatibility
    ./hyprland-uwsm.nix
    ./desktop-common.nix
  ];

  # Make sure the adwaita-qt packages are installed
  environment.systemPackages = with pkgs; [
    adwaita-qt
    adwaita-qt6
  ];
}
