# Hello Lock (lock screen)

Last Updated: 2026-11-02

Hello Lock is an Omarchy shell plugin that replaces the lock screen. Omarchy
routes the lock to the enabled plugin whose manifest says
`clonedFrom: "omarchy.lock"`, so disabling it brings back the stock screen.
It is installed on **p620** and **razer** (issue #2631) by
`hosts/common/nixos/omarchy-hello-lock.nix`. p510 does not import it.

The package is `pkgs/hello-lock`, pinned to a commit of
`denonmaryland/hello-lock` and installed as a store path without its docs,
tests and preview image. The module enables the plugin once per host, on the
first session after the deploy.

## First run and settings

The first shell start with Hello Lock enabled opens a one-time setup (name,
logo, unlock symbol). Settings live in `~/.config/hello-lock/`, which stays
yours and is never managed by Nix.

```bash
omarchy-shell lock settings
```

The same settings are under Style → Lock Screen.

## Previews

```bash
omarchy-shell lock preview
```

## Doctor

The doctor checks the plugin's dependencies and reports any failure.

```bash
~/.config/omarchy/plugins/hello-lock/bin/hello-lock-doctor
```

## Weather

Weather is on by default. Turn it off in the settings above.

## Upgrading

Bump `rev` and `hash` in `pkgs/hello-lock/default.nix`, never
`omarchy plugin update`. Find the latest commit with:

```bash
gh api repos/denonmaryland/hello-lock/commits --jq '.[0].sha'
```

After a nixarchy bump or a hello-lock bump, check that the lock still answers.
Omarchy routes locking to the enabled plugin without checking that it loaded,
so a broken plugin means the screen silently does not lock:

```bash
omarchy-shell lock status
```

Expect JSON with `"passwordPam": true`. An error or no output means the lock
handler is missing: disable hello-lock until it is fixed.

## Recovery from a broken lock

Keep an SSH session open from another host the first time you lock with it.

**Unlocked** (it misbehaves, but you are at the desktop):

```bash
omarchy plugin disable hello-lock && omarchy restart shell
```

The stock lock screen is back. To return, run `omarchy plugin enable hello-lock`
and restart the shell again.

**Locked and it will not unlock:** `omarchy restart shell` refuses to run while
the session is locked, so the command above does not help on its own. From a
TTY (Ctrl+Alt+F3) or over SSH:

```bash
omarchy plugin disable hello-lock
pkill -KILL -f '[.]quickshell-wrapped_'
```

The shell's launcher restarts it after a non-zero exit, and the new shell
re-locks with the stock screen, which unlocks with your password. Omarchy
already sets Hyprland's `misc:allow_session_lock_restore`, so the new shell
can take over the lock. The `[.]` stops `pkill -f` from matching its own
command line. If no shell has come back after a few seconds, run
`omarchy restart shell` from the same terminal.

As a last resort, end the graphical session. This loses unsaved work, and
`loginctl terminate-user` would also end the SSH session you are using:

```bash
loginctl list-sessions
loginctl terminate-session <id of the graphical session>
```
