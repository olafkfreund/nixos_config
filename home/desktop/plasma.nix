{ pkgs, ... }: {

home.packages = with pkgs; [
  kde-gruvbox
  catppuccin-kde
  kde-rounded-corners
  libsForQt5.kdecoration
  libsForQt5.kdeconnect-kde
  libsForQt5.bismuth
  libsForQt5.xdg-desktop-portal-kde
  libsForQt5.gwenview
  libsForQt5.dolphin-plugins
  libsForQt5.ffmpegthumbs
  libsForQt5.kdegraphics-thumbnailers
  libsForQt5.kio
  libsForQt5.kio-extras
  libsForQt5.qtwayland
  libsForQt5.krfb
	plasma-theme-switcher
	utterly-round-plasma-style
	utterly-nord-plasma
	nordic
  libreoffice-qt
  ];
}
