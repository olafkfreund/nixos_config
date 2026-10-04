---
status: draft
issue: 2151
intent: intent/2026-10-04-2151-shell-startup-slow.md
---

# Spec: Omarchy shell responsive within seconds of login

## Design

### 1. quickshell: rescan only when an applications directory really changes

`overlays/upstream-fixes.nix` already overrides `quickshell` (the
QtMultimedia/qtimageformats wrapper), so the package is built locally anyway.
Add a `patches` entry to that same `overrideAttrs`, as a new file
`overlays/patches/quickshell-desktopentry-parent-watch.patch`, against
`src/core/desktopentrymonitor.cpp` and its header.

What the upstream code does: `startMonitoring()` calls
`addPathAndParents()` for every applications directory, so `QFileSystemWatcher`
also watches `~/.local/share`, `~`, `/home`, `/etc`, `/run` and `/`.
`onDirectoryChanged()` restarts a 100 ms debounce for *any* of these, and the
manager then rescans everything.

The parents can't be dropped: on NixOS, `/run/current-system/sw/share/applications`
and `/etc/profiles/per-user/<user>/share/applications` reach a new store path
only when a symlink higher up is replaced (`/run/current-system`,
`/etc/profiles/per-user/<user>`). The store inode itself never changes, so
watching it alone would miss every app installed by a rebuild.

The patch:

- Keeps the parent watches, and records each applications directory's
  `QFileInfo::canonicalFilePath()` when monitoring starts.
- In `onDirectoryChanged(path)`:
  - If `path` is an applications directory or one of its watched
    subdirectories, debounce as now.
  - Otherwise (a parent changed), recompute the canonical paths. If none
    changed, return without rescanning. If any changed, re-add the watches for
    the new targets (a call to `startMonitoring()`, since `addPath` ignores
    duplicates) and debounce.

Result: a file created in `/run`, `~` or `~/.local/share` costs one
`canonicalFilePath()` per applications directory (4 here), not a 550-file
rescan. A generation switch or a new `.desktop` file still triggers exactly
the rescan it needs.

The same change goes upstream as a quickshell issue with the patch attached.
Drop the local patch when nixpkgs ships a release that contains the fix.

### 2. Omamail: never reopen its window at login

Omamail restores its window when `windowOpen` is true in
`~/.config/omamail/window.json` (`ui/Service.qml`, `applyWindowPrefs` →
`reopenWindow`). Add a Home Manager user service on p620 and razer that
rewrites that flag to `false` before the shell starts:

- A `systemd.user.services.omamail-no-restore` oneshot:
  `WantedBy=graphical-session-pre.target`,
  `Before=graphical-session.target`.
- It runs `jq '.windowOpen = false'` on the file, written through a temp file
  and `mv`. It is skipped with `ConditionPathExists=` when the file is absent.
  Every other field (sidebar, zoom, folders, images) is left alone.
- The service lives in a new `hosts/common/nixos/omarchy-omamail.nix`,
  imported by p620 and razer, next to the other `omarchy-*.nix` fragments.
  This follows their pattern (HM block under
  `home-manager.users.olafkfreund`).

The plugin itself is left untouched, so `omarchy plugin update omamail` keeps
working. The bar icon, mail checks, notifications and open-on-click are
unaffected, because they don't read `windowOpen`. An upstream issue asks
huacnlee/omamail for a "reopen window at login" setting. When it lands, the
service is replaced by that setting.

### 3. Plugin removal

Your list: glasschan.oma-swiss, io.github.grichard99.omaproton-vpn,
io.github.jxsparrou.spokenshelf, marcford.gmessages, omarchy.menu.

On your question: no, not every installed plugin appears in `shell.json`.
`PluginRegistry.isEnabled` treats a plugin as on only if `shell.json`
mentions it in `bar.layout`, in `plugins[]` or as `bar.id`. First-party
plugins are on unless they're listed in `disabledPlugins[]`. Today's file:

- **oma-swiss, omaproton-vpn:** not referenced, so already off. Both are
  hand-installed directories. Remove: delete the directory; there's nothing to
  edit in `shell.json`.
- **spokenshelf:** hand-installed and listed in `disabledPlugins`. Remove:
  delete the directory and its `disabledPlugins` entry.
- **gmessages:** Nix-installed by `hosts/common/nixos/omarchy-gmessages.nix`
  (plugin link, user service, `home.packages`), imported by p620 and razer.
  Remove: drop both imports, and delete that file, `pkgs/gmessages-omarchy/`
  and its `customPkgs` entry in `pkgs/default.nix`, which have no other users.
- **omarchy.menu:** a built-in plugin of the Omarchy tree; it can't be
  uninstalled. It's already off through `disabledPlugins`, replaced by
  nixarchy.menu (`defaultPlugins.menu = true`). No change.
- **Leftover backups:** delete `.expose.window-overview.bak.*`,
  `.hancore.voxtype-enhance.bak.*`, `.io.github.nocstah.omacards.bak-1973`,
  `.jankeesvw.herdr.bak.*` and `.olafkfreund.capture.bak.*`.

The directory and `shell.json` edits are user state outside the repo. The plan
makes them a runtime step on each host (p620 and razer, each with its own
`~/.config/omarchy`), done with `omarchy plugin` where it offers a remove, not
a Nix diff.

## Alternatives rejected

- **Drop the parent watches entirely:** misses rebuild-installed apps until the
  next login, which breaks the intent's constraint.
- **Raise the debounce (for example to 2 s):** fewer rescans, but each one
  still blocks the main thread, and at login the burst lasts longer than any
  sane debounce.
- **Patch Omamail's `Service.qml` in place:** the next
  `omarchy plugin update omamail` overwrites it silently.
- **Install Omamail through `programs.nixarchy.plugins` with a patched pinned
  source:** the plugin downloads its own Rust backend at runtime, and a pinned
  frontend falls out of step with it (the omamail backend version-mismatch
  problem we already know about). That's a lot more to maintain for a
  one-field fix.
- **Close the Omamail window before logout:** depends on remembering to; the
  intent says "whatever state it was left in".

## Risks

- **The quickshell patch fails to apply on a nixpkgs bump** (quickshell
  version change). The build fails loudly, on every host that builds the
  overlay, p510 included. Mitigation: the patch touches only one file, which
  hasn't changed upstream since 2025-09-17.
- **A missed rescan:** an applications directory reached through an unexpected
  symlink layout. The canonical-path comparison covers symlink swaps at any
  level, and a real write inside the directory still fires directly.
- **p510 builds the patched quickshell** at its next build. That's harmless,
  but its deploy stays your call.
- **Removing gmessages** stops its user service on p620 and razer, and the
  pairing data stays in `~/.local/share`. Re-adding means reverting the
  commit and pairing again.
- **The `window.json` rewrite** races Omamail only if the shell is already
  running. `Before=graphical-session.target` orders it ahead of
  `omarchy-shell`. Checked in the journal (see Verification).

## Verification

- `just test-host p620` and `just test-host razer` build. `just check-syntax`
  passes.
- After deploying p620 and logging in through SDDM:
  - The shell log (`qs log -r '*.debug=true'` on the current instance) shows
    at most a few "Directory change detected" lines in the first two minutes;
    it was 50 before.
  - `owed` logs "shell background enabled" within about 10 s of the session
    start; it was 61 s before.
  - A `touch ~/foo; rm ~/foo` and a file created in `/run/user/1000` add no
    rescan.
  - `nix profile install nixpkgs#hello`-style changes (a new `.desktop` in
    `~/.local/share/applications`) still show up in the launcher.
- Omamail: leave its window open, log out and back in. The window doesn't
  open, the bar envelope shows the unread count, and clicking it opens the
  inbox. `journalctl --user -u omamail-no-restore` shows it ran before
  `omarchy-shell` started.
- Plugins: `ls ~/.config/omarchy/plugins` shows none of the five removed
  plugins and no `.bak` directories. `marcford.gmessages` has no
  `home.packages` entry left in the p620 closure.
