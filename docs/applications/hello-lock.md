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

## Recovery from a broken lock

Keep an SSH session open from another host the first time you lock with it.

**Unlocked** (it misbehaves, but you are at the desktop):

```bash
omarchy plugin disable hello-lock && omarchy restart shell
```

The stock lock screen is back. To return, run `omarchy plugin enable hello-lock`
and restart the shell again.

**Locked and it will not unlock:** `omarchy restart shell` refuses to run while
the session is locked, so the command above does not help. From a TTY
(Ctrl+Alt+F3) or over SSH:

```bash
omarchy plugin disable hello-lock
export XDG_RUNTIME_DIR=/run/user/1000
export HYPRLAND_INSTANCE_SIGNATURE=$(ls /run/user/1000/hypr | head -1)
hyprctl keyword misc:allow_session_lock_restore 1
```

Then stop the shell process. Its process name is `.quickshell-wrapped_`, so
`pgrep -x quickshell` misses it, and `pkill -f` on a pattern in your own command
line kills your shell instead. When the shell starts again, it locks with the
stock screen, which unlocks with your password. If the shell does not come
back, end the session with `loginctl terminate-user "$USER"`; this loses
unsaved work.
