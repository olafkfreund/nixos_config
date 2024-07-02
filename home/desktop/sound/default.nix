{ pkgs, ...}: {
  home.packages = with pkgs; [
    qpaeq
    pulseeffects-legacy
    gxmatcheq-lv2
    easyeffects
    jamesdsp
    plex-media-player
    # fcast-client
    # fcast-receiver
  ];
}
