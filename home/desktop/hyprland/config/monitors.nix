# Hyprland Monitor Configuration
# Host-specific monitor setup using variables from host configuration
{ host, ... }:
let
  inherit
    (import ../../../../hosts/${host}/variables.nix { })
    laptop_monitor
    external_monitor
    ;
in
{
  # Use extraConfig for monitor configuration since it requires dynamic evaluation
  # Monitor configurations need string interpolation from host variables
  wayland.windowManager.hyprland.extraConfig = ''
    ${laptop_monitor}
    ${external_monitor}
  '';
}
