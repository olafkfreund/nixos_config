---
status: draft
issue: 3144
author: olafkfreund
---

# Intent: make pkg, podman, flatsnap and govee safe to unload

Split from #3139 by the owner's decision of 2026-11-20. herdr was done in
# 3139.

## Problem

nixarchy.pkg, nixarchy.podman, nixarchy.flatsnap and olafkfreund.govee
still set `"keepLoaded": true`, so the shell builds all four menus at
login. None of them starts a process before it is opened, so this costs
construction time only. #3139 kept them loaded because each menu owns
processes that change state, and Quickshell kills a child process when its
`Process` object is destroyed:

| Plugin | Menu-owned processes that would die on unload |
|---|---|
| pkg | `_writer`, `_reindexer`, `_check` and the deferred apply, the in-panel apply, `_applyTerm` |
| podman | `actionProcess` in the menu's own `PodmanState`, `copyProcess` |
| flatsnap | `_writer`, `_apply` before `systemd-run` takes over, `_ack` |
| govee | `GoveeClient`: the running command and the queue behind it |

govee also differs from the rest in two ways:

- it is a hand copy of `omagovee/plugin`, not installed declaratively;
- it unloads on every Esc or click-away (`dismiss()` calls `shell.hide`).

## Proposed outcome

- None of the four menus is built at login. Each loads on its first open.
- Closing a menu mid-action never kills the action. Each action runs to
  completion, and reopening the menu shows its result.
- The bar widgets and their IPC keep working before the first open and
  after an unload.
- govee hides on Esc and click-away like the other menus. Only a
  toggle-close or `shell hide` unloads it.
- govee is installed from a flake input through
  `programs.nixarchy.plugins`, not copied by hand.

## Affected users and systems

- Repos:
  - olafkfreund/nixarchy-pkg (`main`);
  - olafkfreund/nixarchy-podman (`master`);
  - olafkfreund/nixarchy-flatsnap (`main`);
  - olafkfreund/omagovee (`main`);
  - this repo's `flake.nix`, which needs input overrides for the three
    nixarchy plugins ahead of edge, as in #3107, plus a new omagovee input
    and its module.
- Hosts: p620 and razer. p510 only with the owner's OK.

## Constraints

- Changes go to the plugins' own repos as PRs.
- No behaviour loss beyond what each PR states.
- The repo rules apply as usual: worktrees, a bus post before a switch,
  and p510 only with the owner's OK.

## Open questions

None. The owner decided govee's hide behaviour and its flake input on
2026-11-20.
