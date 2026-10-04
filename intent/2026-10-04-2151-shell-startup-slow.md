---
status: draft
issue: 2151
author: olafkfreund
---

# Intent: Omarchy shell responsive within seconds of login

## Problem

After the SDDM login on p620 on 2026-10-04, the Hyprland session was up in
2 s (17:15:13). The Omarchy shell didn't answer IPC until 17:16:14, so the bar
and the wallpaper handoff waited about a minute. Three causes are behind it:

1. **quickshell rescans desktop entries far too often.** quickshell 0.3.1's
   `DesktopEntryMonitor` (`src/core/desktopentrymonitor.cpp`,
   `addPathAndParents`) watches each applications directory and every parent
   up to `/`. That includes `~/.local/share`, `~`, `/home`, `/etc`, `/run` and
   `/`. A create or delete in any of them runs a full rescan of about 550
   `.desktop` files on the shell's main thread, with a 100 ms debounce. It ran
   50 times during login (26,000 of the 30,000 shell log lines), and it keeps
   firing during the session (17:22:00, with no change in any applications
   directory). The upstream code is unchanged since 59f5744f (2025-09-17).
2. **Omamail opens at login.** It reopens its window whenever the window was
   open at the previous logout (`windowOpen` in `~/.config/omamail/window.json`,
   restore logic in `ui/Service.qml`), and no setting turns this off. It isn't
   wanted at login or startup.
3. **The plugin set adds load.** `~/.config/omarchy/plugins` holds about 30
   plugins: some are Nix-linked, some are hand-installed directories, and some
   are leftover `.bak` directories. Not all of them are in use.

## Proposed outcome

- After an SDDM login on p620, the bar and the wallpaper are up within a few
  seconds of the session starting. The log shows at most a handful of
  "Directory change detected" rescans during login, not dozens.
- Omamail doesn't open a window at login, whatever state it was left in. Its
  bar icon and mail checking keep working, and it still opens on click.
- Plugins you don't use are removed, and the leftover `.bak` directories are
  gone.

## Affected users and systems

- p620 and razer: both run the Omarchy session, and quickshell comes from the
  shared overlay `overlays/upstream-fixes.nix`. p510 also runs Omarchy and
  takes the same overlay.
- quickshell (the Omarchy shell), the Omamail plugin, and
  `~/.config/omarchy/plugins` / `shell.json` for olafkfreund.

## Constraints

- p510 is never built or deployed without asking. A quickshell overlay change
  reaches it too, so its deploy is a separate decision.
- The fix must not lose new or removed applications: a newly installed app
  must still show up in the launcher without a re-login.
- No change to Omamail's mail behaviour (refresh, notifications, bar count).
- Hand-installed plugins are user-owned directories that nixarchy never
  replaces. Removing one means deleting the directory and its `shell.json`
  entry, not a Nix change.
- Upstream first where the bug is upstream: file the quickshell and Omamail
  issues as well as any local patch.

## Open questions

1. **Which plugins go?** Enabled in `shell.json`: rmacy.voxtype-osd, vimarchy,
   io.github.olafkfreund.nixi, olafkfreund.github-actions,
   olafkfreund.gitlab-pipelines, nixarchy.flatsnap, nixarchy.winvm,
   aziz.hyprforge. Disabled already: io.github.jxsparrou.spokenshelf,
   omarchy.menu. Installed but not listed there, among them:
   io.github.nobledoodle.omarchroma, glasschan.oma-swiss, nixarchy.microvm,
   nixarchy.podman, nixarchy.devenv, io.github.cempack.omaspotify,
   io.github.data-goblin.omgato, io.github.grichard99.omaproton-vpn,
   io.github.huey-holdings-llc.omarecorder, io.github.kristoferlund.webcam,
   io.github.arikisonfire.bar-folder, olafkfreund.govee,
   shavanced.notification-center, marcford.gmessages, onelegdave.omadroid,
   olafkfreund.ai-mirror. You choose; the spec then lists exactly those.
2. **Omamail's window restore:** patch it locally (it's a hand-installed git
   clone of huacnlee/omamail, which `omarchy plugin update` would overwrite),
   bring it under `programs.nixarchy.plugins` with a pinned, patched source, or
   only file upstream for a "reopen window at login" setting?
3. **Should the quickshell patch go to razer as well as p620?** It's one
   overlay, so it lands on every host that rebuilds. p510 only on your say-so.
