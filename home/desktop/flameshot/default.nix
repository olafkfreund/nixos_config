{ pkgs
, config
, lib
, ...
}:
with lib; let
  cfg = config.desktop.screenshots.flameshot;
in
{
  options.desktop.screenshots.flameshot = {
    enable = mkEnableOption {
      default = false;
      description = "Enable FlameShot screenshots";
    };
  };
  config = mkIf cfg.enable {
    services.flameshot = {
      enable = true;
      package = pkgs.flameshot.override { enableWlrSupport = true; };
      settings = {
        General = {
          showStartupLaunchMessage = false;
          showHelp = false;
          uiColor = "#ff0000"; # Customize UI color
          contrastUiColor = "#ffffff";
          saveAsFileExtension = "png";
          savePath = "/home/${config.home.username}/Pictures/screenshots";
          copyPathAfterSave = false;
          startupLaunch = true; # Auto-start on login
        };
        Shortcuts = {
          TYPE_ARROW = "A";
          TYPE_RECTANGLE = "R";
          TYPE_CIRCLE = "C";
          TYPE_MARKER = "M";
          TYPE_TEXT = "T";
        };
      };
    };
  };
}
