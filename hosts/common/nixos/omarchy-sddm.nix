{ config, lib, ... }:
# Run SDDM's Wayland greeter inside Hyprland, not weston.
#
# This matches what upstream Omarchy ships. Its etc/sddm.conf.d/10-wayland.conf:
#
#     [Wayland]
#     CompositorCommand=start-hyprland -- --config /usr/share/sddm/hyprland.lua
#
# nixarchy vendors that greeter config (default/sddm/hyprland.lua: animations
# off, no logo, no splash) but never sets compositorCommand, so NixOS' weston
# default wins by omission and the vendored file goes unused.
#
# CORRECTION. An earlier version of this comment claimed weston's greeter "never
# comes up" on razer's Optimus NVIDIA, citing SDDM::Auth::HELPER_TTY_ERROR. That
# was wrong, and the error says so if you read it:
#
#     [PAM] Authenticating... [PAM] returning.          <- auth SUCCEEDED
#     Failed to take control of "/dev/tty1" ("olafkfreund"): Operation not permitted
#     Auth: sddm-helper exited with 5                   <- HELPER_TTY_ERROR
#
# sddm-helper emits that from one place, UserSession.cpp: ioctl(TIOCSCTTY)
# failing with EPERM, which the kernel returns when the tty is already some other
# session's controlling terminal. It runs as root, so it is not permissions, and
# it happens BEFORE the compositor is exec'd -- so no compositor, weston or
# Hyprland, was ever on the failing path.
#
# What actually held tty1: a logind session created by greetd, stuck in
# State=closing since 28 Aug on a machine that had not rebooted since 24 Aug.
# SDDM's own VT picker (Display.cpp fetchAvailableVt) skips sessions in
# `closing`, so it believed tty1 was free, claimed VT 1, and then could not take
# it. Six failures and the daemon exits 23, systemd trips the start limit, and
# the machine has no login manager.
#
# The fix was a reboot. Nothing here fixes it.
#
# This override is kept because it matches upstream, not because weston is known
# to be broken here -- weston has never actually been observed failing on this
# hardware. If a greeter problem ever recurs, check `loginctl list-sessions` for
# a closing session on a VT before touching the compositor.
#
# mkForce because the nixpkgs default is a plain assignment, not mkDefault.
{
  # Hyprland directly, not start-hyprland: programs.hyprland.withUWSM is on
  # here, and the wrapper expects a systemd user session the sddm greeter user
  # does not have. SDDM execs this command itself and needs neither uwsm nor
  # the `--` separator upstream's config-file form uses.
  services.displayManager.sddm.wayland.compositorCommand = lib.mkForce (
    "${config.programs.hyprland.package}/bin/Hyprland --config "
    + "${config.programs.nixarchy.package}/share/omarchy/default/sddm/hyprland.lua"
  );
}
