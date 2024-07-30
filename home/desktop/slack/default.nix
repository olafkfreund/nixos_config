{ lib
, pkgs
, ...
}:
# let
#   slack = pkgs.slack.overrideAttrs (old: {
#     installPhase =
#       old.installPhase
#       + ''
#         rm $out/bin/slack
#
#         makeWrapper $out/lib/slack/slack $out/bin/slack \
#           --prefix XDG_DATA_DIRS : $GSETTINGS_SCHEMAS_PATH \
#           --prefix PATH : ${lib.makeBinPath [pkgs.xdg-utils]} \
#           --add-flags "--ozone-platform=wayland --enable-features=UseOzonePlatform,WebRTCPipeWireCapturer"
#       '';
#   });
# in
{
  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/slack" = "slack.desktop";
  };

  home.packages = [ pkgs.slack ];
}
