{
  pkgs,
  config,
  lib,
  ...
}: let
  # Detect if KDE Plasma is enabled (this is a simplistic check)
  isPlasmaEnabled = config.desktop.plasma.enable or false;

  # Set appropriate platformTheme name based on desktop environment
  platformThemeName =
    if isPlasmaEnabled
    then "kde"
    else "gnome";

  # Use a dark theme by default
  styleName = "adwaita-dark";
  stylePackage = pkgs.adwaita-qt;
in {
  qt = {
    # Configure platformTheme as a set with a name attribute
    platformTheme = {
      name = platformThemeName;
    };
    style = {
      name = styleName;
      package = stylePackage;
    };
  };

  home.packages = with pkgs; [
    # Qt5 styling
    libsForQt5.qtstyleplugin-kvantum

    # Qt6 styling
    qt6Packages.qtstyleplugin-kvantum

    # Adwaita theme for Qt applications
    adwaita-qt
    adwaita-qt6

    # Include Breeze theme for KDE integration
    libsForQt5.breeze-qt5
  ];

  # Add environment variables for better Qt application integration
  home.sessionVariables = lib.mkIf (platformThemeName == "gnome") {
    # Force Qt apps to use the GTK theme when using GNOME-based environments
    QT_QPA_PLATFORMTHEME = "adwaita";
  };
}
