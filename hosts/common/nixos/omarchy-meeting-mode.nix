# nixarchy-meeting-mode: quiet desktop during calls. While a call app (Meet,
# Zoom, Teams, ...) uses the microphone it turns on do-not-disturb, keeps the
# screen awake, switches night light off and stops omarchy-voice.service. After
# the call (15 s by default) it puts back only what it changed, so voice starts
# again only if it was running.
#
# One-time step per machine:
#   omarchy plugin enable nixarchy.meeting-mode --section center
{ inputs, ... }:
{
  home-manager.users.olafkfreund =
    { pkgs, ... }:
    {
      programs.nixarchy.plugins."nixarchy.meeting-mode".src =
        inputs.nixarchy-meeting-mode.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };
}
