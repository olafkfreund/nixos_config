# OmaDroid: mirror and control an Android phone from the Omarchy bar (scrcpy +
# adb). The package carries its own tool paths, so nothing else is installed.
# Its Install buttons (pacman) and KDE Connect row show as unavailable here.
#
# One-time per machine: omarchy plugin enable onelegdave.omadroid
{ pkgs, ... }:
{
  home-manager.users.olafkfreund.programs.nixarchy.plugins."onelegdave.omadroid".src =
    pkgs.customPkgs.omadroid;
}
