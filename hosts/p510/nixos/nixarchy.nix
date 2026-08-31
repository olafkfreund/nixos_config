{ inputs, ... }:
# Omarchy on the headless media server, as a selectable session only.
#
# This host is class headless-rdp: it already runs X, GNOME and GDM, and
# gnome-remote-desktop serves that GNOME session over RDP. Nixarchy joins as an
# extra entry; nothing that keeps the box reachable changes. Three settings do
# the work, and each one is here because leaving it out breaks something
# measurable:
#
#   displayManager = false
#     The nixarchy module turns SDDM on by default. Verified by evaluating this
#     host with it left alone: services.displayManager.sddm.enable flipped
#     false -> true, which would swap the display manager out from under the
#     RDP path on a machine with no monitor attached.
#
#   defaultSession = "gnome"
#     autoLogin is on here (user olafkfreund) and defaultSession was unset, so
#     NixOS picked the session for us. Adding Omarchy changed
#     sessionData.autologinSession from "gnome" to "omarchy" -- the server
#     would have booted into Hyprland instead of the session RDP serves.
#     Pinning it keeps autologin on GNOME regardless of what else is offered.
#
#   omarchy-sole-hyprland.nix
#     Same reason as p620: the nixarchy module enables programs.hyprland, which
#     registers a second, config-less Hyprland session next to Omarchy's.
#
# Deliberately NOT imported from p620's setup: omarchy-sddm.nix (GDM stays),
# nixarchy-apps.nix (that is the desktop app selection and has no business in
# this closure), and the stylix theme hook (nobody switches themes here).
{
  imports = [
    inputs.nixarchy.nixosModules.nixarchy
    ../../common/nixos/omarchy-sole-hyprland.nix
  ];

  programs.nixarchy.enable = true;
  programs.nixarchy.user = "olafkfreund";
  programs.nixarchy.displayManager = false;

  # Omarchy's preinstalled application set, off. It is the bulk of what
  # nixarchy costs here: with it on the closure went 50.52 -> 57.56 GiB, and
  # the additions are desktop software this host has no use for -- cef-binary
  # (1.9 GiB, the runtime behind the web-app wrappers), Pinta, cliamp,
  # KDDockWidgets, CUPS. The session itself still works; only the app bundle
  # is skipped. Media-server packages come from this host's own modules.
  programs.nixarchy.preinstalls = false;

  services.displayManager.defaultSession = "gnome";
}
