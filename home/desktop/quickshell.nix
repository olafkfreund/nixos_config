# QuickShell Standalone Module
# Can be imported conditionally based on features
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.features.desktop;
in
{
  config = mkIf cfg.quickshell {
    # QuickShell package and dependencies
    home.packages = with pkgs; [
      quickshell
      qt6.qtbase
      qt6.qtdeclarative
      qt6.qtwayland
      qt6.qtsvg
      qt6.qt5compat
    ];

    # QuickShell configuration files
    home.file = {
      # Main QuickShell configuration
      ".config/quickshell/config.json".text = builtins.toJSON {
        theme = "gruvbox-dark";
        bar = {
          position = "top";
          height = 32;
          transparent = true;
          offset = 0;
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
        colors = {
          background = "#1d2021";
          foreground = "#ebdbb2";
          accent = "#d79921";
          urgent = "#cc241d";
          warning = "#d65d0e";
          success = "#98971a";
        };
      };

      # Main QML entry point
      ".config/quickshell/main.qml".source = ./hyprland/quickshell/components/main.qml;

      # Bar component
      ".config/quickshell/bar.qml".source = ./hyprland/quickshell/components/bar.qml;

      # Widget components
      ".config/quickshell/widgets/WorkspaceIndicator.qml".source = ./hyprland/quickshell/components/widgets/WorkspaceIndicator.qml;
      ".config/quickshell/widgets/Clock.qml".source = ./hyprland/quickshell/components/widgets/Clock.qml;
      ".config/quickshell/widgets/SystemTray.qml".source = ./hyprland/quickshell/components/widgets/SystemTray.qml;
      ".config/quickshell/widgets/BatteryIndicator.qml".source = ./hyprland/quickshell/components/widgets/BatteryIndicator.qml;
      ".config/quickshell/widgets/NetworkIndicator.qml".source = ./hyprland/quickshell/components/widgets/NetworkIndicator.qml;
      ".config/quickshell/widgets/AudioIndicator.qml".source = ./hyprland/quickshell/components/widgets/AudioIndicator.qml;
    };

    # Auto-start QuickShell with Hyprland
    wayland.windowManager.hyprland.settings.exec-once = [
      "quickshell"
    ];

    # Layer shell rules for QuickShell
    wayland.windowManager.hyprland.settings.layerrule = [
      "blur,quickshell"
      "ignorealpha[0.2],quickshell"
      "animation slide top,quickshell"
    ];
  };
}
