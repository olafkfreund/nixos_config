# Omapop: PopClip-style action bar on mouse text selection (Omarchy shell).
# Tool paths are baked into the package; hyprctl is the compositor nixarchy runs.
# One-time per machine: omarchy plugin enable io.github.jondkinney.omapop
# Upgrade by bumping rev + hash in pkgs/omapop, never `omarchy plugin update`.
{ config, pkgs, ... }:
{
  home-manager.users.olafkfreund.programs.nixarchy.plugins."io.github.jondkinney.omapop".src =
    pkgs.customPkgs.omapop.override { hyprland = config.programs.hyprland.package; };
}
