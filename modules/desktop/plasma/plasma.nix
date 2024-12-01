{
  inputs,
  config,
  lib,
  pkgs,
  pkgs-stable,
  ...
}: {
  environment.systemPackages = with pkgs; [
    kdePackages.xdg-desktop-portal-kde
    kdePackages.polkit-kde-agent-1
    kdePackages.qt6ct
    kdePackages.qt6gtk2
    #Other
    libreoffice-qt
    pywal
    wpgtk
    polychromatic
    quaternion
  ];
}
