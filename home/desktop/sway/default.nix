{
  config,
  lib,
  ...
}: 
with lib; let
  cfg = config.desktop.sway;
in {
  options.desktop.sway = {
    enable = mkEnableOption {
      default = false;
      description = "sway";
    };
  };
  config = mkIf cfg.enable {
    wayland.windowManager.sway = {
      enable = true;
      xwayland = true;
      wrapperFeatures.gtk = true;
      systemd = {
        enable = true;
        xdgAutostart = true;
      };
      extraSessionCommands = ''
        '';
      config = {
        terminal = "foot";
        startup = [
          { command = "foot"; }
          { command = "wayvnc 0.0.0.0"; }
          { command = "waybar"; }
        ];
      };
    };
  };
}
