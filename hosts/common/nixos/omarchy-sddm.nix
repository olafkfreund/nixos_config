{ config, lib, ... }:
# Run SDDM's Wayland greeter inside Hyprland, not weston.
#
# NixOS defaults services.displayManager.sddm.wayland.compositorCommand to
# `weston --shell=kiosk`. On razer's Optimus hybrid NVIDIA that greeter never
# comes up: sddm-helper crashes with exit 1, the journal shows
# SDDM::Auth::HELPER_TTY_ERROR, systemd hits the restart limit, and the machine
# is left with no login manager. It is the same class of failure that made this
# host avoid GDM -- a greeter compositor, not the display manager itself.
#
# Upstream Omarchy never used weston. Its etc/sddm.conf.d/10-wayland.conf says:
#
#     [Wayland]
#     CompositorCommand=start-hyprland -- --config /usr/share/sddm/hyprland.lua
#
# The greeter runs in Hyprland, which already works on this hardware -- it is
# the session both hosts log into. nixarchy vendors that greeter config
# (default/sddm/hyprland.lua: animations off, no logo, no splash) but never
# sets compositorCommand, so NixOS' weston default won by omission.
#
# mkForce because the nixpkgs default is a plain assignment, not mkDefault.
{
  services.displayManager.sddm.wayland.compositorCommand = lib.mkForce (
    "${config.programs.hyprland.package}/bin/start-hyprland -- --config "
    + "${config.programs.nixarchy.package}/share/omarchy/default/sddm/hyprland.lua"
  );
}
