---
status: approved
issue: 2218
author: olafkfreund
---

# Intent: ship the fleet-guard and nix-flavour mods from the repo

## Problem

Claude Code 2.1.287+ supports mods: plugins of TypeScript hooks that run
inside Claude Code and can draw in its interface or intervene in tool calls.
Two were prototyped and tried in a session on 2026-10-07:

- **fleet-guard:** when Claude is about to run a command that disrupts a
  shared host (a deploy, GC, store optimise, service restart or reboot), it
  holds the call. It then asks the user in a dialog that shows the latest
  `#agents` messages. On approval it posts the announcement to the agent bus
  itself and passes the command on carrying the markers the managed guards
  look for. Today those markers are asserted by the model; with the mod they
  follow a human click. It also hard-denies backticks inside
  `git commit -m "..."` (the incident that ran a live deploy) and
  `home-manager switch`. Its classifier's table test found Issue #2215.
- **nix-flavour:** NixOS-themed spinner and turn-end words. Its status line
  shows the host, the system generation, whether a reboot is pending for a
  new kernel, and the current Omarchy theme.

Both live only in that session's mods folder
(`~/.claude/dev-mods/<session-id>/`). They are unversioned and unreviewed,
load only in sessions on p620 that enable that folder, and never reach razer
or p510.

## Proposed outcome

- Both mods live in the repo with their tests, and they are reviewed and
  versioned like any other change.
- Every new Claude Code session on the chosen hosts loads them with no manual
  step, and `/plugin` lists them as active.
- A change to a mod reaches the hosts through the normal update flow.
- The managed settings hooks stay exactly as they are. fleet-guard sits on top
  of them and never replaces them, because Codex, agy and `claude -p` sessions
  don't load mods.

## Affected users and systems

- Every interactive Claude Code session on the hosts that get the mods.
- `~/.claude/`, which Syncthing syncs between hosts. Nix-store symlinks
  inside it break the sync (see `home/syncthing-stignore.nix`), so the mods
  must reach Claude Code some other way.
- The agent bus (`#agents`): fleet-guard reads it under its own cursor
  (`agent: "fleet-guard"`) and posts announcements.
- `modules/programs/claude-code-managed.nix` and/or
  `home/development/claude-code*.nix`, depending on the loading mechanism the
  spec chooses.

## Constraints

- No Nix-store symlinks inside `~/.claude/` (Syncthing).
- Managed settings stay the floor. The mod must not weaken any managed guard,
  and it must fail open to them: if it can't ask (headless, a dismissed
  dialog, an unreachable bus), the managed guards decide as before.
- The mods API is early access and changes between releases. The mods must
  pass `claude plugin validate` and `claude plugin test` against the pinned
  Claude Code version, and a Claude Code bump must not leave a broken mod in
  every session unnoticed.
- p510 is not built or deployed without asking.
- Explicit imports only; services and features stay behind flags in
  `modules/`.

## Open questions

1. **Hosts.** Decided: p620 and razer only. All three, or p620 and razer only? p510 is a desktop now and
   runs Claude Code (2.1.280+), but the agent-bus Stop-hook wake is p620/razer
   only, so it's unclear whether its sessions have the bus MCP that
   fleet-guard reads.
2. **Loading mechanism.** Decided: managed scope for fleet-guard (a guard),
   user scope for nix-flavour (a preference). User scope (a folder marketplace or
   `CLAUDE_CODE_PLUGIN_DIRS` in `~/.claude/settings.json`'s `env`), or managed
   scope (the organization's managed-mods setting in
   `/etc/claude-code/managed-settings.json`)? Managed scope fits fleet-guard
   as a guard the user shouldn't disable by accident, but the header of
   `claude-code-managed.nix` says user preferences such as `enabledPlugins`
   don't belong there. nix-flavour is plainly a preference. The spec should
   settle this, possibly a different answer for each mod.
3. **nix-flavour's theme path.** Decided: keep reading
   `nixarchy-theme.nix`, the file that manages the theme. It reads
   `~/.config/nixos/nixarchy-theme.nix` directly. Keep that, or have Nix
   inject the path? The checkout path is the same on every host.
