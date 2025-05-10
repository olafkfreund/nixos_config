{
  pkgs,
  config,
  lib,
  ...
}: let
  # Detect if KDE Plasma is enabled
  isPlasmaEnabled = config.desktop.plasma.enable or false;

  # Set appropriate platformTheme name based on desktop environment
  platformThemeName =
    if isPlasmaEnabled
    then "kde"
    else "gnome";
in {
  qt = {
    enable = true;
    platformTheme = lib.mkForce {
      name = platformThemeName;
      package =
        if isPlasmaEnabled
        then pkgs.libsForQt5.qtstyleplugin-kvantum
        else pkgs.adwaita-qt;
    };
    style = lib.mkForce {
      name = "adwaita-dark";
      package = pkgs.adwaita-qt;
    };
  };

  home.packages = with pkgs; [
    # Qt theming packages
    libsForQt5.qtstyleplugin-kvantum
    qt6Packages.qtstyleplugin-kvantum
    adwaita-qt
    adwaita-qt6
  ];

  # Add environment variables for Qt application integration
  home.sessionVariables = lib.mkIf (!isPlasmaEnabled) {
    # Use GNOME theme by default except in KDE Plasma
    QT_QPA_PLATFORMTHEME = "gnome";
  };
}
