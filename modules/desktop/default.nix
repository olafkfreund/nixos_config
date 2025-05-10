{pkgs, ...}: {
  # Make sure the adwaita-qt packages are installed
  environment.systemPackages = with pkgs; [
    adwaita-qt
    adwaita-qt6
  ];
}
