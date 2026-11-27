---
status: draft
issue: 3265
author: olafkfreund
---

# Intent: Bus, p510 and checkout guards for Codex and agy

## Problem

Three host guards protect the shared machines: the agent-bus announcement
before a deploy, garbage collection, restart or reboot; the p510 deploy guard;
and the guard that keeps `~/.config/nixos` on `main`. They run only inside
Claude Code (`modules/programs/claude-code-managed.nix`). Codex sessions skip
them, and plain agy sessions run with `--dangerously-skip-permissions` and no
guard at all. The only guard the three tools share is the coder guard, and
that one is active only for implementers.

Separately, the agy `coder-guard` entry in `~/.gemini/config/hooks.json` is
only added when its key is missing (`home/development/antigravity-config.nix`),
so a changed entry never reaches the file, and `agy-implement`'s strict check
then refuses to start.

## Proposed outcome

- Codex and agy sessions are held to the same three host guards as Claude
  Code, with the same messages and the same escape prefixes
  (`AGENT_BUS_ANNOUNCED=1`, `P510_DEPLOY_APPROVED=1`,
  `SHARED_CHECKOUT_BRANCH_OK=1`).
- The agy hooks.json entries this repo owns are kept equal to their Nix
  values.
- The guard tests cover the Codex and agy payload shapes and run in
  `just test-guards`.

## Affected users and systems

Codex and agy on p620 and razer (and p510, where the managed module also
runs: rule changes only, no p510 build or deploy).

## Constraints

- One guard implementation each; only registration and payload translation
  are per tool.
- A missing `/etc` file on a host must not break agy (hooks.json is
  Syncthing-synced).
- Codex has no "ask" decision; the guards already only allow (0) or deny (2).

## Open questions

None.
