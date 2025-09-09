{ pkgs, ... }: {
  imports = [
    ./hyprland-uwsm.nix
    ./desktop-common.nix
    ./gnome-remote-desktop.nix
  ];

  # Make sure the adwaita-qt packages are installed
  environment.systemPackages = with pkgs; [
    adwaita-qt
    adwaita-qt6
    wldash # Moved from desktop/wldash/default.nix
  ];
}
