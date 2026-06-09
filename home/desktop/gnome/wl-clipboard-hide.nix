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
  #      overview / launcher. It does NOT hide running windows from the
  #      dock's running-apps section (#808's original commit message
  #      hoped it would; on GNOME 50 it doesn't).
  #
  #   2. The real fix: tmux is configured to use OSC-52 instead of
  #      wl-copy for clipboard sync (see home/shell/tmux/default.nix —
  #      `set -g set-clipboard on` + `copy-pipe-and-cancel` without a
  #      wl-copy target). The outer terminal (kitty) handles the actual
  #      clipboard write, so wl-copy is never spawned by tmux and the
  #      dummy toplevels never appear.
  #
  # Why not `wl-paste --watch` to drain selections? That requires the
  # wlr-data-control / ext-data-control Wayland protocol, which Mutter
  # has declined to implement — the exact same root cause. `wl-paste`
  # one-shot reads still work (used for middle-click paste in tmux),
  # only the `--watch` mode requires data-control.
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
