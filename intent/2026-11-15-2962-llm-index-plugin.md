---
status: draft
issue: 2962
author: olafkfreund
---

# Intent: bump llm-index to the identity fix and install its shell plugin

## Problem

- **The identity fix isn't deployed.** On p620, llm-index's `source` root
  (`/mnt/code/Source-home`) has been `offline / identity mismatch` since
  2026-11-14. After a restart, the disk came up as `/dev/sdd1` instead of
  `/dev/sdc1`, and the old identity check treated it as another filesystem.
  Code search for every agent on p620 has served a frozen snapshot since then.
  The fix is merged upstream (nixarchy-llm-index#17), but this repository pins
  the input at `491f256`, which predates it. razer has the same exposure: its
  `/extdisk` is a second NVMe.
- **The shell plugin isn't installed.** The llm-index Omarchy shell plugin
  (nixarchy-llm-index#15, merged in #16) is on neither host, so an offline
  root, a stopped service or a long first index is still invisible on the
  desktop.

## Proposed outcome

- **Input bump.** `nixarchy-llm-index` is pinned to the merged main
  (`54e0fbe`), on p620 and razer.
- **p620 recovers.** After deploy, its `source` root goes
  `identity check`, then `ok`, after one scan with no reindex. If the file
  evidence check fails, the approved fallback is a one-off
  `adoptUuid = "bdd8461e-7d6c-42b6-9cfe-39967825dd42"`, removed again
  afterwards.
- **The `olafkfreund.llm-index` shell plugin on both hosts:**
  - installed through `programs.nixarchy.plugins`;
  - enabled once through `local.omarchy.enableOnce`, so a later disable in
    Setup > Plugins sticks;
  - opened with `SUPER + CTRL + ALT + I` (`local.omarchy.keys.extra`);
  - reachable from an `apps.llm-index` menu row
    (`programs.nixarchy.menu.extraEntries`).

  All four are as decided in nixarchy-llm-index's approved
  `spec/2026-11-15-15-shell-plugin.md` and plan step 6.

## Affected users and systems

- `hosts/common/nixos/llm-index.nix`, which p620 and razer import, and
  `flake.nix`/`flake.lock`.
- Hosts: p620, then razer (deployed via p620). p510 is not involved.
- Every agent's code search on p620 (it recovers), and the owner's desktop
  on both hosts (the new plugin).

## Constraints

- **Usual rules:**
  - work in a worktree;
  - deploy from main;
  - announce on the agent bus before deploying;
  - p510 untouched;
  - agents don't commit or deploy.
- **The private tier stays private.** Only the public MCP server stays
  registered with cloud agents, as now.
- **No shell.json writes from Nix.** Enabling goes through the existing
  `enableOnce` hook.
- **`SUPER + CTRL + ALT + I` must still be free** on both hosts. The keys
  module fails the build on a duplicate.

## Open questions

None. The design decisions were approved upstream (#15 spec and plan
step 6, #14 spec).
