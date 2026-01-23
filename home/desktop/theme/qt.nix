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
        else pkgs.qt6Packages.qt6ct
      );
    };
    # Set Breeze dark style for consistent KDE/Qt dark mode
    style = {
      name = lib.mkForce "breeze";
      package = lib.mkForce pkgs.kdePackages.breeze;
    };
  };

  # GNOME/GTK dark mode via dconf (for KDE apps that respect it)
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = lib.mkDefault "prefer-dark";
    gtk-theme = lib.mkDefault "Adwaita-dark";
  };

  # Combine all home.* attributes into a single block
  home = {
    packages = with pkgs; [
      # Qt theming packages
      libsForQt5.qtstyleplugin-kvantum
      qt6Packages.qtstyleplugin-kvantum
      adwaita-qt
      adwaita-qt6
      qt6Packages.qt6ct

      # KDE/Breeze theming packages (breeze supports both Qt5 and Qt6)
      # Note: breeze-icons removed to avoid conflict with gruvbox-plus-icons
      kdePackages.breeze
    ];

    # KDE globals configuration for dark mode
    # This ensures KDE applications use dark theme even outside Plasma
    file.".config/kdeglobals" = {
      text = ''
        ${builtins.readFile "${pkgs.kdePackages.breeze}/share/color-schemes/BreezeDark.colors"}
      '';
    };

    # Add environment variables for Qt application integration
    sessionVariables = {
      # Use qt6ct by default except in KDE Plasma
      QT_QPA_PLATFORMTHEME = lib.mkForce (if isPlasmaEnabled then "kde" else "qtct");
      # KDE color scheme for Qt apps
      KDE_COLOR_SCHEME = "BreezeDark";
      # Ensure Qt apps use dark mode
      QT_STYLE_OVERRIDE = lib.mkDefault "breeze";
    };
  };
}
