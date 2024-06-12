{ pkgs, ... }: {

home.packages = with pkgs; [
  # libsForQt5.kdeconnect-kde
  libsForQt5.xdg-desktop-portal-kde
  libsForQt5.wayland
  libsForQt5.qtwayland
  # kdePackages.kdeconnect-kde
  kdePackages.xdg-desktop-portal-kde
  kdePackages.wayland
  kdePackages.wayland-protocols
  kdePackages.qtwayland
  libreoffice-qt
  ];
}
