# QuickShell Configuration Module
# Provides modern QtQuick-based desktop shell alongside existing Waybar
{ config, lib, pkgs, hyprlandFeatures ? { }, hyprlandTheme ? { }, ... }:
with lib;
let
  cfg = hyprlandFeatures.quickshell or { };
  theme = hyprlandTheme;

  # Default configuration
  defaultConfig = {
    enable = false;
    bar = {
      position = "top";
      height = 32;
      transparent = true;
      offset = 0; # Pixel offset from screen edge
    };
    widgets = {
      workspaces = true;
      clock = true;
      systemTray = true;
      battery = true;
      network = true;
      audio = true;
    };
    animations = {
      enabled = true;
      duration = 200;
      curve = "ease-out";
    };
  };

  # Merge user config with defaults
  finalConfig = recursiveUpdate defaultConfig cfg;
in
mkIf finalConfig.enable {
  # QuickShell package and dependencies
  home.packages = with pkgs; [
    quickshell
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwayland
    qt6.qtsvg
    qt6.qtquickcontrols2
  ];

  # QuickShell configuration files
  home.file = {
    # Main QuickShell configuration
    ".config/quickshell/config.json".text = builtins.toJSON {
      theme = theme.name or "gruvbox-dark";
      bar = finalConfig.bar;
      widgets = finalConfig.widgets;
      animations = finalConfig.animations;
      colors = {
        background = theme.colors.background or "#1d2021";
        foreground = theme.colors.foreground or "#ebdbb2";
        accent = theme.colors.accent or "#d79921";
        urgent = theme.colors.urgent or "#cc241d";
        warning = theme.colors.warning or "#d65d0e";
        success = theme.colors.success or "#98971a";
      };
    };

    # Main QML entry point
    ".config/quickshell/main.qml".source = ./components/main.qml;

    # Bar component
    ".config/quickshell/bar.qml".source = ./components/bar.qml;

    # Widget components
    ".config/quickshell/widgets/WorkspaceIndicator.qml".source = ./components/widgets/WorkspaceIndicator.qml;
    ".config/quickshell/widgets/Clock.qml".source = ./components/widgets/Clock.qml;
    ".config/quickshell/widgets/SystemTray.qml".source = ./components/widgets/SystemTray.qml;
    ".config/quickshell/widgets/BatteryIndicator.qml".source = ./components/widgets/BatteryIndicator.qml;
    ".config/quickshell/widgets/NetworkIndicator.qml".source = ./components/widgets/NetworkIndicator.qml;
    ".config/quickshell/widgets/AudioIndicator.qml".source = ./components/widgets/AudioIndicator.qml;
  };

  # Auto-start QuickShell with Hyprland (alongside existing bars)
  wayland.windowManager.hyprland.settings.exec-once = [
    "quickshell"
  ];

  # Layer shell rules for QuickShell (ensure it stays on top layer)
  wayland.windowManager.hyprland.settings.layerrule = [
    "blur,quickshell"
    "ignorealpha[0.2],quickshell"
    "animation slide top,quickshell"
  ];
}
