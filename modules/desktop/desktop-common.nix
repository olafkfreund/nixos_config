{
  lib,
  config,
  ...
}:
with lib; let
  cfg = config.modules.desktop.common;
in {
  options.modules.desktop.common = {
    enable = mkEnableOption "Common desktop environment configuration";
    enableHyprland = mkEnableOption "Enable Hyprland as the window manager";
  };

  config = mkIf cfg.enable {
    # Enable Hyprland with UWSM if selected
    modules.desktop.hyprland-uwsm.enable = cfg.enableHyprland;

    # Add other common desktop config here (fonts, themes, etc.)
  };
}
