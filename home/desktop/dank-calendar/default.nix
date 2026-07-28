{ ... }:
# DankCalendar (dcal) — the calendar daemon behind the DankMaterialShell
# calendar card. It syncs Local/Google/Microsoft/CalDAV/iCloud accounts and
# serves them over a unix socket; DMS's CalendarDankBackend discovers
# $XDG_RUNTIME_DIR/dankcal-*.sock and prefers it over the khal backend, which
# is read-only and needs a vdirsyncer pipeline to feed it.
#
# Unlike Noctalia (see ../noctalia), this DOES run from its systemd user
# service on graphical-session.target, GNOME included. The rule that keeps
# Noctalia out of systemd is about a *shell* spawning a second time over
# gnome-shell; dcal is a headless sync daemon, so a GNOME session just keeps
# the calendars warm and nothing collides.
#
# Accounts are attached imperatively, once per machine — OAuth refresh tokens
# rotate, so they live in the login keyring (org.freedesktop.secrets) rather
# than agenix:
#
#   dcal account add evolution        # reuse GNOME Online Accounts via EDS
#   dcal account add google --credentials ~/.config/gogcli/credentials.json
#
# The second form works because gogcli's client is an "installed" (Desktop)
# OAuth app: Google accepts any loopback port for those, so dcal's callback
# needs no registered redirect URI, and that project already has the Calendar
# and Tasks APIs enabled.
{
  programs.dank-calendar = {
    enable = true;
    systemd.enable = true;
  };
}
