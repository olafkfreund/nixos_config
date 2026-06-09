{ config, lib, ... }:
let
  inherit (lib) mkIf;
  cfg = config.desktop.gnome;
in
{
  # GNOME/Mutter deliberately does not implement the wlr-data-control or
  # ext-data-control Wayland protocols. When wl-copy runs on GNOME it has
  # to fake a window (an xdg_toplevel with app_id
  # `io.github.bugaevc.wl-clipboard`) just to be allowed to participate
  # in the clipboard. GNOME Shell then sees that toplevel as a "running
  # app" and shows it in the dock — once per wl-copy invocation. This
  # also tends to steal focus, breaking copy/paste workflows in practice.
  #
  # Two complementary defences are wired in this repo:
  #
  #   1. This file — a NoDisplay .desktop entry mapped to the wl-clipboard
  #      app_id, which keeps the entry out of the app grid / Activities
  #      overview / launcher.
  #
  #   2. wl-paste-watch.nix — a user systemd service that runs
  #      `wl-paste --watch` so each wl-copy's data is consumed
  #      immediately, the supersession event fires deterministically,
  #      and the dummy toplevel exits. This is what actually keeps the
  #      dock clean. On GNOME 50+ at least, NoDisplay does NOT hide
  #      running windows from the dock's running-apps section —
  #      contrary to what the original commit message of this file
  #      (#808) hoped for.
  #
  # Filename matters: GNOME maps app_id -> <app_id>.desktop, so the entry
  # key here must be the literal `io.github.bugaevc.wl-clipboard` string.
  # Exec is a no-op (`true`) — this file exists only to hide the toplevel.
  config = mkIf cfg.enable {
    xdg.desktopEntries."io.github.bugaevc.wl-clipboard" = {
      name = "wl-clipboard";
      type = "Application";
      exec = "true";
      noDisplay = true;
      startupNotify = false;
      settings = {
        StartupWMClass = "io.github.bugaevc.wl-clipboard";
        NoDisplay = "true";
      };
    };
  };
}
