{
  pkgs,
  pkgs-stable,
  ...
}: {
  home.packages = with pkgs; [
    kdePackages.xdg-desktop-portal-kde
    kdePackages.polkit-kde-agent-1
    kdePackages.qt6ct
    kdePackages.qt6gtk2
    libsForQt5.qt5.qtwayland
    kdePackages.qtwayland
    #Other
    libreoffice-qt
    pywal
    wpgtk
    polychromatic
    quaternion
  ];
}
