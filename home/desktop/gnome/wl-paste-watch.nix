{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.desktop.gnome;
in
{
  # Drain the Wayland CLIPBOARD selection so wl-copy zombies don't pile up
  # in the GNOME dock.
  #
  # Background: GNOME/Mutter doesn't implement wlr-data-control or
  # ext-data-control. wl-copy therefore creates a dummy xdg_toplevel
  # (app_id io.github.bugaevc.wl-clipboard) to participate in the
  # clipboard, and that toplevel renders as a dock icon. wl-copy is
  # supposed to exit when superseded by the next clipboard owner, but on
  # Mutter the `cancelled` event delivery is unreliable — so tmux's
  # `copy-pipe-and-cancel wl-copy` accumulates a process (and a dock
  # icon) per yank. We've seen this go past 25.
  #
  # Running `wl-paste --watch` forces an immediate read of every new
  # selection, which makes the supersession/cleanup deterministic on
  # Mutter: each new wl-copy sees its data delivered and the prior one
  # gets cancelled and exits cleanly.
  #
  # We pipe to `cat` and discard — Clipboard Indicator
  # (extensions.nix) already provides the history UI by polling
  # St.Clipboard from inside gnome-shell, so storing the data twice
  # would be pointless. The watcher exists only for its consumption
  # side-effect.
  #
  # PRIMARY selection isn't watched: tmux's copy-pipe targets CLIPBOARD,
  # not PRIMARY. Add a second service if some other tool starts using
  # PRIMARY heavily.
  config = mkIf cfg.enable {
    systemd.user.services.wl-paste-watch = {
      Unit = {
        Description = "Drain Wayland CLIPBOARD to make wl-copy exit cleanly on GNOME";
        # Wait for the graphical session so $WAYLAND_DISPLAY is set.
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };

      Service = {
        # `wl-paste --watch` long-runs and invokes the command on every new
        # selection. `cat` reads stdin to EOF (wl-paste closes it after each
        # selection) and discards.
        ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.coreutils}/bin/cat";
        StandardOutput = "null";
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
