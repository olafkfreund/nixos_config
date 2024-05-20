{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    qt6.qtmultimedia
    libsForQt5.qt5.qtmultimedia
    libsForQt5.qt5.qtgraphicaleffects
    qt6.qtquick3d
    qt6.qtquicktimeline
    libsForQt5.qt5.qtquickcontrols
    qt6.qtquick3dphysics
    libsForQt5.qt5.qtquickcontrols2
    qt6.qtquickeffectmaker
    libsForQt5.sddm-kcm
    libsForQt5.phonon-backend-gstreamer
  ];
}
