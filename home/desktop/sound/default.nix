{ pkgs, lib, osConfig, ... }: {
  home.packages = with pkgs; [
    qpaeq
    # gxmatcheq-lv2
    # fcast-client
    # fcast-receiver
  ];

  # Live (video) wallpapers stay silent (#2318): owed plays the audio track and
  # upstream has no mute option, so drop the track via libmpv. Extends
  # nixarchy's own Environment list on the unit.
  systemd.user.services.owed.Service.Environment =
    lib.mkIf (osConfig.programs.nixarchy.owe.enable or false) [ "OWE_MPV_OPTIONS=aid=no" ];
}
