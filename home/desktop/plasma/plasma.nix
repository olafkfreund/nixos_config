{ pkgs, ... }: {

home.packages = with pkgs; [
 
  libsForQt5.qtwayland
  kdePackages.xdg-desktop-portal-kde
  kdePackages.wayland
  kdePackages.wayland-protocols
  kdePackages.qtwayland
  kdePackages.polkit-kde-agent-1
  kdePackages.qt6ct
  kdePackages.qt6gtk2
  #Other
  libreoffice-qt
  pywal
  wpgtk
  polychromatic
  ungoogled-chromium
  quaternion
  xwaylandvideobridge
  ];
}
