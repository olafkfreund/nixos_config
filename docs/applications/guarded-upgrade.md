# Guarded upgrade

The nightly `nixos-upgrade` timer runs `scripts/guarded_upgrade.py` (module `modules/nix/guarded-upgrade.nix`).
It switches a host only inside its window and only when nobody is using it. With a session open, that needs a
fresh idle report in `/run/guarded-upgrade-idle/<uid>` (nixarchy#1946).

## The idle report

- `guarded-idle-report` (user unit, graphical session) runs a second `hypridle` from the Nix store with one
  15-minute listener. On idle it starts `guarded-idle-beat`; on resume it stops it.
- `guarded-idle-beat` rewrites the report every 60 s. The gate refuses a report older than 120 s, so a beat
  that dies reads as not idle.
- The beat reports nothing unless its own `hypridle` owns `org.freedesktop.ScreenSaver` (only the owner
  receives inhibitors such as a video or a call), and the newest `Inhibit locks:` line in that run's journal
  is 0. hypridle 0.1.8 runs no `on-resume` when an inhibitor arrives after the timeout, so its log is the only
  place the count shows. A run with no `found N rules` startup line in the journal reports nothing.
- The gate reads only the file of the single live session's user, and only when that user owns it.

## Hardening exceptions

`guarded-idle-report` and `guarded-idle-beat` are user units. `DynamicUser` would write the report as a
different uid, which the gate rejects by design. `ProtectSystem = "strict"` and `ProtectHome` require mount
namespacing that user units lack. `NoNewPrivileges = true` is kept on both, because neither runs a setuid
program.

`guarded-upgrade-recover` (p620, at boot) runs as root without `DynamicUser`: it starts and inspects
the four runner units and owns their `drain/` directories, which a dynamic user cannot. It never
switches, so it runs with `ProtectSystem = "strict"`, `ProtectHome`, `PrivateTmp` and
`NoNewPrivileges`. Its only writable paths are its own state and cache directories and
`/var/lib/github-runner`, plus `/run/lock` for the deploy lock.
