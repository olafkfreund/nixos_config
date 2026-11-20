---
status: draft
issue: 3139
author: olafkfreund
---

# Intent: make herdr, pkg, podman, govee and flatsnap safe to unload

Follow-up to #3107 (shell startup) and #3118 (login still slow).

## Problem

Five Omarchy shell plugins still set `"keepLoaded": true`: nixarchy.herdr,
nixarchy.pkg, nixarchy.podman, olafkfreund.govee and nixarchy.flatsnap.
The shell builds every keepLoaded panel at startup, so all five load and run their models at
login, even though each is only opened from a keybind or bar click.

The #3107 audit kept them on purpose. Each one runs a child process, or
holds the queue for one, inside the menu view. Quickshell kills a child when
its `Process` object is destroyed (`process.cpp:31-37`, quickshell v0.3.2),
so unloading the view on a toggle-close would kill work in flight:

| Plugin | Work that lives in the view |
|---|---|
| pkg | an in-panel apply runs `nixarchy-apply` as a menu child process |
| podman | stop and prune run in the menu's own `PodmanState` instance |
| flatsnap | `_apply` (`FlatsnapModel.qml:401`, owned by `Menu.qml:44`) can die before `systemd-run` hands the build to its unit |
| herdr | session creation runs `actionProc` in the menu's `HerdrModel` (`HerdrModel.qml:1400-1412`) |
| govee | `GoveeClient` (its queue and running command) is a menu child; every close calls `shell.hide` (`GoveeMenu.qml:45-48,126`) |

## Proposed outcome

- None of the five is built at login. Each loads on first open, as
  devenv, distrobox, microvm and winvm do since #3107.
- Closing a panel mid-action, whether by toggle-close, `shell hide` or Esc, never kills the
  action. An apply, container stop or prune, flatsnap build, herdr
  session creation and queued Govee command all run to completion, and
  reopening the panel shows their current state.
- The bar widgets keep working while their menus are unloaded.

## Affected users and systems

- Repos: olafkfreund/nixarchy-herdr, nixarchy-pkg, nixarchy-podman,
  nixarchy-flatsnap and omagovee. The installed govee plugin
  (`~/.config/omarchy/plugins/olafkfreund.govee`, copied by hand) is
  identical to `omagovee/plugin`.
- This repo: `flake.nix` pins for the four nixarchy plugins ahead of edge
  (the #3107 override pattern), and a way to install the updated govee plugin.
- Hosts: p620 and razer run these plugins. p510 runs the Omarchy desktop
  too, but it is never built or deployed without the owner's OK.

## Constraints

- Changes to the plugins go to their own repos as PRs (the owner chose this
  for #3107), not as patches applied here at install time.
- No behaviour loss beyond what each PR states. A known loss is allowed
  only when no caller depends on it (#3107 accepted `status` answering
  `unknown` until first open).
- Login timing is measured with the #3118 startup probe, before and after.
- The usual repo rules apply: worktrees only, a bus announcement before a
  switch, and p510 only with the owner's OK.

## Open questions

1. herdr is the heaviest to change (`HerdrModel` is large). Ship all five in
   one task, or herdr in its own follow-up?
2. govee is not packaged: it is a hand copy of `omagovee/plugin`. Package it
   as a flake input like the others, or keep copying it by hand after the
   PR merges?
