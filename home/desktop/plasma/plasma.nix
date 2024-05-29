{ pkgs, ... }: {

home.packages = with pkgs; [
 
  libsForQt5.qtwayland
  kdePackages.xdg-desktop-portal-kde
  # kdePackages.dolphin
  # kdePackages.dolphin-plugins
  # kdePackages.kio-gdrive
  # kdePackages.kio-extras
  # kdePackages.kio
  kdePackages.wayland
  kdePackages.wayland-protocols
  kdePackages.qtwayland
  kdePackages.kdeconnect-kde
  kdePackages.polkit-kde-agent-1
  kdePackages.qt6ct
  kdePackages.qt6gtk2
  #KDE6
  # kdePackages.wayqt
  # kdePackages.kcmutils
  # kdePackages.kgpg
  # kdePackages.krfb
  # kdePackages.ksvg
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
