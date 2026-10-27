---
status: draft
issue: 2505
author: olafkfreund
---

# Intent: Microsoft Teams (Synechron) as an Omarchy plugin on p620

## Problem

Synechron work happens in Microsoft Teams. Today that means a browser tab or
web app. There's no unread badge in the bar, and notifications only work while
the tab is open somewhere.

omateams (Divanyx/omateams, MIT, 1.4.1) solves that: it runs the real Teams
web client in its own Omarchy-themed QtWebEngine window, with an unread badge
in the bar, desktop notifications, calls, meetings and screen sharing. It was
tested on p620 on 2026-10-27, built from source with Nix into a throwaway
profile, and **Synechron's Microsoft sign-in accepted it**.

It can't be installed the documented way here. `install.sh --if-needed`,
which the plugin runs whenever the shell loads it, checks `pacman` and
compiles `host/` with `qmake6` into `~/.local/share/omateams/bin`. That's
unpinned, built outside Nix, and fails or drifts on NixOS.

## Proposed outcome

- On p620, after a deploy, Teams is in the Omarchy bar: an unread badge, Teams
  opening in its themed window, and desktop notifications.
- The app and plugin are built by Nix, pinned in this repo, and upgraded by a
  bump. The plugin never compiles anything or writes into `~/.local/share` at
  runtime, apart from Teams' own login profile and settings.
- You sign in to Synechron once inside omateams, and the session survives
  restarts, deploys and reboots.
- Camera, microphone and screen sharing work in calls.
- Nothing else changes: the Synechron Chrome profile and its web apps stay as
  they are, and can still be used side by side.

## Affected users and systems

- Hosts: p620 (where the test ran). razer is an open question.
- Files: a new `pkgs/omateams` (the host app and plugin), a new
  `hosts/common/nixos/omarchy-omateams.nix` (as with omapop, #2498), and the
  host's `nixos/nixarchy.nix` import.
- State that stays yours: `~/.local/share/omateams/` (the Teams login
  profile) and `~/.config/omateams/` (settings).

## Constraints

- Build from source with Nix (QtWebEngine comes from the binary cache, so only
  the small app compiles). Follow the omapop pattern: `substituteInPlace
  --replace-fail` for paths, wired through
  `programs.nixarchy.plugins.<id>.src`.
- No API keys or stored credentials: you sign in interactively, and the
  session lives only in the app's own profile.
- Don't touch the Chrome profiles.
- Restart the shell cleanly after enabling (memory: hot-reload can leave two
  shells running).
- The camera is the Facecam Pro, which drops off USB behind the Genesys hub
  when streaming starts (seen 2026-10-27; you replugged it). That's hardware,
  outside this change, but a call test depends on it.

## Open questions

1. **Hosts:** p620 only, or razer too?
2. **Start hidden at login** (upstream default `runInBackground = true`):
   unread badge and notifications from login, costing roughly one browser tab
   of RAM (upstream says up to 2 GB on a busy tenant before it recycles). Or
   start it only when you open it?
3. **Enabling:** like Altscape (#2503), automatic once at first login, or a
   one-time `omarchy plugin enable omateams`?
