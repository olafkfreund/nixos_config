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
  - Code search for every agent on p620 has served a frozen snapshot since
    then.
  - The fix is merged upstream (nixarchy-llm-index#17), but this repository
    pins the input at `491f256` (`flake.nix:153`), which predates it.
  - razer has the same exposure: its `/extdisk` is a second NVMe.
- **The shell plugin isn't installed.** The llm-index Omarchy shell plugin
  (nixarchy-llm-index#15, merged in #16) is on neither host, so an offline
  root, a stopped service or a long first index is still invisible on the
  desktop.

## Proposed outcome

Two stages, in this order, each deployed from main.

**Stage 1: the identity fix (input bump only).**

- `nixarchy-llm-index` is pinned to the merged main (`54e0fbe`, which
  includes #16 and #17), on p620 first.
- **p620:** `source` goes `identity check`, then `ok`, after one complete
  scan. File and chunk counts stay unchanged, apart from real edits, and
  `fs_uuid` is recorded. If the file evidence check fails, the approved
  fallback (#14 spec) is a **p620-only** `adoptUuid` for `source`
  (`bdd8461e-7d6c-42b6-9cfe-39967825dd42`).
  - It's set through a host-scoped option, never in the shared module.
  - It goes in as its own small change, merged to main and deployed.
  - It's removed again once `source` is `ok`.
- **razer:** its first index has already finished (both roots `ok`,
  2026-11-15). After the bump, both roots stay `ok` with no index data lost.
  `fs_uuid` is recorded once a complete scan passes the evidence check. It
  may stay empty for a while, which is safe. No `adoptUuid` on razer.
- **Gate:** stage 2 starts only after p620's `source` is back to `ok`.

**Stage 2: the shell plugin.** Installed on both hosts, as approved upstream
(the #15 spec, section 4, and plan step 6):

- installed through `programs.nixarchy.plugins`;
- enabled once through `local.omarchy.enableOnce` (a post-boot hook), so a
  later disable in Setup > Plugins sticks;
- opened with `SUPER + CTRL + ALT + I` (`local.omarchy.keys.extra`);
- reachable from an `apps.llm-index` menu row
  (`programs.nixarchy.menu.extraEntries`).

It is checked live from the running shell after a re-login, on p620 before
razer.

Upstream planned two separate steps. Doing the bump and the plugin as two
gated stages of one task here keeps that order.

## Affected users and systems

- `flake.nix` and `flake.lock` (stage 1).
- `hosts/common/nixos/llm-index.nix`, which p620 and razer import (stage 2).
- A p620 host file, only if the `adoptUuid` fallback is needed.
- Hosts: p620, then razer (deployed via p620). p510 doesn't import the
  module and isn't touched.
- Every agent's code search on p620 (it recovers), and the owner's desktop
  on both hosts (the new plugin).

## Constraints

- **Usual rules:**
  - work in a worktree;
  - every deploy from main, after merge;
  - announce on the agent bus before each deploy;
  - p510 untouched;
  - agents don't commit or deploy.
- **The private tier stays private.** Only the public MCP server stays
  registered with cloud agents, as now.
- **The plugin's runtime needs must hold on both hosts:**
  - `llm-index` on the shell session's PATH with the default config path.
    The module's `home.packages = [ cfg.package ]` (`llm-index.nix:47`)
    stays;
  - `omarchy-launch-floating-terminal-with-presentation`, for Open log;
  - the default Omarchy bar, which summons bar widgets.

  The live checks confirm them.
- **No `shell.json` writes from Nix.** Enabling goes through the existing
  `enableOnce` hook. It runs after the shell starts, so the live check
  includes a re-login.
- **`SUPER + CTRL + ALT + I` must be free.** It's unused in the shared and
  host key declarations. The keys module's build check only covers its own
  `shared`, `extra` and `external` lists, so a live check confirms the key
  on both hosts.

## Open questions

None. The design decisions were approved upstream:

- #15: the spec and plan step 6;
- #14: the spec, including the `adoptUuid` fallback.

This intent only sets the order and the host scope.
