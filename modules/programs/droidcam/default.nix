{
  self,
  config,
  lib,
  pkgs,
  username,
  ...
}:
with lib; let
  cfg = config.media.droidcam;
in {
  options.media.droidcam = {
    enable = mkEnableOption {
      description = "Enable Droicam";
      default = false;
    };
  };
  config = mkIf cfg.enable {
    programs.droidcam.enable = true;
    services.usbmuxd.enable = true;
    environment.shellAliases = {
      webcam = "droidcam-cli -size=1920x1080 4747";
    };
    home-manager.users.${username} = {
      xdg.desktopEntries = {
        droidcam = {
          name = "Droidcam";
          exec = "${pkgs.droidcam}/bin/droidcam";
          terminal = false;
          categories = [
            "Video"
            "AudioVideo"
          ];
        };
      };
    };
  };
}
