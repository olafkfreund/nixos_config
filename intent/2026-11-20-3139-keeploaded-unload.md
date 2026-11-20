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
The shell builds the menu of every keepLoaded plugin at startup, although
each menu is only opened on demand (a keybind or `nixarchy-plugin <id>`).

What that costs at login differs:

- **herdr** is the only one that does work at login. Its menu builds its own
  `HerdrModel`, whose `Component.onCompleted: appStart()`
  (`HerdrModel.qml:1482`) spawns `hc events --json`, starts a watchdog,
  runs `herdr-sessions app-list --remote` on events and opens three
  `FileView`s. The bar widget (`Panel.qml:54-57`) already runs a second,
  separate `HerdrModel`.
- **pkg, podman, flatsnap and govee** only build their QML tree at login.
  None starts a process or timer until `open()`.

The #3107 audit kept all five loaded on purpose. Quickshell kills a child
process when its `Process` object is destroyed (`process.cpp:31-37`,
quickshell v0.3.2), and each menu owns processes that change state:

| Plugin | Menu-owned processes that would die on unload |
|---|---|
| pkg | `_writer` (writes flake and package files), `_reindexer` (a cache rebuild of several minutes), `_check` with an apply deferred behind it, the in-panel apply, `_applyTerm` (a `Process`, not `execDetached`) |
| podman | `actionProcess` in the menu's own `PodmanState` (start, stop, restart, remove, prune, stop-all), `copyProcess` |
| flatsnap | `_writer` (`add`/`rm` in `flatsnap.nix`), `_apply` before `systemd-run` takes over (`FlatsnapModel.qml:401`), `_ack` |
| herdr | `actionProc` (new, open, focus, delete, app-new, app-focus, app-interrupt), `killProc` (kill, app-kill) |
| govee | `GoveeClient`: the running command and the rest of its queue |

## Proposed outcome

- At login no menu of the five is built, and herdr's menu-side `hc events`
  process and its remote app list no longer start.
- What unloads a menu is the same as for the #3107 plugins. A toggle-close
  or `shell hide` unloads it. Esc or a click-away hides it if it has been
  opened once. When a menu unloads, nothing in the table above dies. The
  work runs to completion, and when the menu is reopened it shows the
  result: the refreshed state, plus any error that arrived while it was
  closed.
- Deliberate cancellation stays. herdr's close still cancels an open prompt
  (`cancelInput()`, `Menu.qml:89-94`) and its remote host polls.
- Bar widgets and their IPC keep working before the first menu open and
  after an unload. This covers herdr's IPC target and podman's bar-side
  `stopAll`.
- It is observable in two ways. A login shows no menu-side `hc events`
  process for herdr. A shell log or probe shows that none of the five menus
  is constructed before the first open.

## Affected users and systems

- Repos: olafkfreund/nixarchy-herdr, nixarchy-pkg, nixarchy-podman,
  nixarchy-flatsnap and omagovee. The installed govee plugin
  (`~/.config/omarchy/plugins/olafkfreund.govee`, copied by hand) is
  identical to `omagovee/plugin`.
- This repo: `flake.nix` pins the four nixarchy plugins ahead of edge (the
  #3107 override pattern), and something must install the updated govee
  plugin.
- Hosts: p620 and razer. p510 runs the Omarchy desktop too, but it is never
  built or deployed without the owner's OK.

## Constraints

- Changes to the plugins go to their own repos as PRs (the owner chose this
  for #3107), not as patches applied here at install time.
- No behaviour loss beyond what each PR states. A known loss is allowed only
  when no caller depends on it (#3107 accepted `status` answering
  `unknown` until first open).
- The usual repo rules apply: worktrees only, a bus announcement before a
  switch, and p510 only with the owner's OK.

## Open questions

1. **Scope.** herdr is the only plugin of the five that does work at login,
   and it is also the hardest to change. For the other four, the saving is
   only QML construction time, which is unmeasured and probably small. The
   options are:
   - all five;
   - herdr only;
   - herdr first, the other four in a follow-up.
2. **govee unload.** `GoveeMenu.qml` calls `shell.hide` on Esc and on a
   click-away (`dismiss()`, lines 44-47, called at 63 and 153). Without
   `keepLoaded` it would unload on every close and build again on every
   open. Should it keep that, or hide like the other menus?
3. **govee install.** govee is a hand copy of `omagovee/plugin`. Should it
   be packaged as a flake input like the others, or keep being copied by
   hand after its PR merges?
