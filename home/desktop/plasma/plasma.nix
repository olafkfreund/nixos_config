{ pkgs, ... }: {

home.packages = with pkgs; [
 
  #KDE5
  #kde-gruvbox
  # libsForQt5.kdecoration
  # libsForQt5.kdeconnect-kde
  # #libsForQt5.bismuth
  # libsForQt5.xdg-desktop-portal-kde
  # libsForQt5.gwenview
  # libsForQt5.dolphin-plugins
  # libsForQt5.ffmpegthumbs
  # libsForQt5.kdegraphics-thumbnailers
  # libsForQt5.kio
  # libsForQt5.kio-extras
  libsForQt5.qtwayland
  # libsForQt5.krfb
  # libsForQt5.qtstyleplugins
  # libsForQt5.discover
  # libsForQt5.qmltermwidget
  # libsForQt5.sddm-kcm
  # libsForQt5.phonon-backend-gstreamer
  #libsForQt5.kaccounts-integration
  #libsForQt5.kaccounts-providers
  #libsForQt5.packagekit-qt
  #libsForQt5.qt5.qtsvg
  #libportal-qt5
  #libsForQt5.qt5.qtmultimedia
  #libsForQt5.qt5.qtgraphicaleffects
  #libsForQt5.qt5.qtquickcontrols2
  #libsForQt5.qt5.qtquickcontrols
  #KDE6
  # kdePackages.wayqt
  # kdePackages.kcmutils
  # kdePackages.kgpg
  # kdePackages.krfb
  kdePackages.ksvg
  # kdePackages.waylib
  # kdePackages.wayqt
  # kdePackages.wayland-protocols
  # kdePackages.syntax-highlighting
  # kdePackages.qwlroots
  # kdePackages.okular
  # kdePackages.neochat
  # kdePackages.polkit-kde-agent-1
  # kdePackages.syntax-highlighting
  # kdePackages.polkit-kde-agent-1
  # kdePackages.sddm
  # kdePackages.sddm-kcm
  # kdePackages.kdeconnect-kde
  # kdePackages.kpackage
  # kdePackages.plasma-wayland-protocols
  # nixos-bgrt-plymouth
  # kdePackages.qgpgme
  # # kdePackages.qt6ct
  # # kdePackages.qt6gtk2
  # kdePackages.plymouth-kcm
  # kdePackages.plasmatube
  # kdePackages.audiotube
  # kdePackages.breeze
  # # kdePackages.breeze-gtk
  # # kdePackages.breeze-grub
  # kdePackages.breeze-plymouth
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
