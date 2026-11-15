{ config
, lib
, pkgs
, username
, ...
}:
let
  inherit (lib) mkIf;
  cfg = config.features.media;
in
{
  config = mkIf cfg.droidcam {
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
