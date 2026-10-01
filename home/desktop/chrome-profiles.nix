{ config, lib, ... }:
with lib; let
  cfg = config.programs.chromium;
  slug = label: replaceStrings [ "." ] [ "-" ] (toLower label);
  chromeDir = "${config.home.homeDirectory}/.config/google-chrome";
in
{
  options.programs.chromium.profileLaunchers = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        directory = mkOption {
          type = types.str;
          description = "Chrome profile directory name, e.g. \"Profile 2\".";
        };
        picture = mkOption {
          type = types.bool;
          default = false;
          description = "Use the profile's Google Profile Picture as the icon.";
        };
      };
    });
    default = { };
    description = "Desktop launcher per Chrome profile, keyed by label.";
  };

  config = mkIf (cfg.enable && cfg.profileLaunchers != { }) {
    xdg.desktopEntries = mapAttrs'
      (label: p:
        nameValuePair "chrome-profile-${slug label}" {
          name = "Chrome — ${label}";
          # finalPackage carries the host's commandLineArgs
          exec = "${getExe' cfg.finalPackage "google-chrome-stable"} \"--profile-directory=${p.directory}\" %U";
          icon =
            if p.picture
            then "${chromeDir}/${p.directory}/Google Profile Picture.png"
            else "google-chrome";
          categories = [ "Network" "WebBrowser" ];
          type = "Application";
          terminal = false;
        })
      cfg.profileLaunchers;
  };
}
