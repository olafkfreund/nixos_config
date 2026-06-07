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
  # We can't fix the underlying protocol mismatch from NixOS, but we can
  # provide a NoDisplay .desktop entry mapped to the same app_id via
  # StartupWMClass. GNOME Shell then associates the dummy toplevel with
  # this entry and suppresses it from the app grid (and on most GNOME
  # versions, from the dock's running-apps list too).
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
