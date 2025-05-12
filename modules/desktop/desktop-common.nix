{
  lib,
  config,
  ...
}: {
  options.modules.desktop.common = {
    enable = lib.mkEnableOption "Common desktop environment configuration";
    enableHyprland = lib.mkEnableOption "Enable Hyprland as the window manager";
  };

  config = lib.mkIf config.modules.desktop.common.enable {
    # Enable Hyprland with UWSM if selected
    modules.desktop.hyprland-uwsm.enable = config.modules.desktop.common.enableHyprland;

    # Add other common desktop config here (fonts, themes, etc.)
  };
}
