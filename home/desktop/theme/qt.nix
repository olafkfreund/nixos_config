{ pkgs
, config
, lib
, ...
}:
let
  # Detect if KDE Plasma is enabled
  isPlasmaEnabled = config.desktop.plasma.enable or false;

  # Set appropriate platformTheme name based on desktop environment
  platformThemeName =
    if isPlasmaEnabled
    then "kde"
    else "qtct";
in
{
  qt = {
    enable = true;
    platformTheme = {
      name = lib.mkForce platformThemeName;
      package = lib.mkForce (
        if isPlasmaEnabled
        then pkgs.libsForQt5.qtstyleplugin-kvantum
        else pkgs.qt6ct
      );
    };
    style = {
      name = lib.mkForce "adwaita-dark";
      package = lib.mkForce pkgs.adwaita-qt;
    };
  };

  home.packages = with pkgs; [
    # Qt theming packages
    libsForQt5.qtstyleplugin-kvantum
    qt6Packages.qtstyleplugin-kvantum
    adwaita-qt
    adwaita-qt6
    qt6ct
  ];

  # Add environment variables for Qt application integration
  home.sessionVariables = lib.mkIf (!isPlasmaEnabled) {
    # Use qt6ct by default except in KDE Plasma
    QT_QPA_PLATFORMTHEME = lib.mkForce "qtct";
  };
}
