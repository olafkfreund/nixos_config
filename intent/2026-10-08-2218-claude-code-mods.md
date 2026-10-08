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

- **fleet-guard:** the prototype held disruptive commands (deploy, GC,
  restart, reboot) behind an approval dialog. That cannot work: managed
  PreToolUse hooks run before any mod sees a tool call, and their block is
  final, so the managed bus-announce and p510 guards block first. Revised on
  2026-10-08 by the user's decision: the managed guards stay authoritative,
  and fleet-guard adds visibility. It shows a band above the prompt with who
  is mid-flight on `#agents`, adds an `/announce` command that posts for the
  user without a Claude turn, and keeps its hard denies for backticks inside
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
- The managed settings hooks stay exactly as they are and stay the only
  enforcement of the bus and p510 rules. fleet-guard adds visibility on top and
  replaces nothing, because the managed hooks run first anyway, and Codex, agy
  and `claude -p` sessions don't load mods.

## Affected users and systems

- Every interactive Claude Code session on the hosts that get the mods.
- `~/.claude/`, which Syncthing syncs between hosts. Nix-store symlinks
  inside it break the sync (see `home/syncthing-stignore.nix`), so the mods
  must reach Claude Code some other way.
- The agent bus (`#agents`): fleet-guard reads it under its own cursor and
  posts what the user asks `/announce` to post.
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
