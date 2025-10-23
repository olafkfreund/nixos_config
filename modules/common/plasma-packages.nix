{pkgs, ...}: {
  # Define common packages used in both home-manager and system config
  plasmaCommonPackages = with pkgs; [
    kdePackages.xdg-desktop-portal-kde
    kdePackages.polkit-kde-agent-1
    kdePackages.qt6ct
    # kdePackages.qt6gtk2  # Disabled due to incompatibility with Qt 6.10 (missing private headers)
    # libreoffice-qt
    pywal
    wpgtk
    polychromatic
  ];

  # Additional packages only for home-manager
  plasmaHomePackages = with pkgs; [
    libsForQt5.qt5.qtwayland
    kdePackages.qtwayland
  ];
}
