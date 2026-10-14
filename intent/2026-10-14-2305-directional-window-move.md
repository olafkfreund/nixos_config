---
status: approved
issue: 2305
author: olafkfreund
---

# Intent: windows move across displays and groups with one key, and groups stay on the right screen

## Problem

`hosts/common/nixos/omarchy-workspaces.nix` makes SUPER+1..0 switch every
display together (a "group" is workspace N, N+10 and N+20). It does that job,
but moving a *window* around a multi-monitor desk still takes several keys, and
several parts of the setup quietly work against the groups.

1. **No single "move this window that way" key.** Moving a window to the next
   screen, or off the edge of the desk into the next group, needs SUPER+SHIFT+N
   plus focus changes. The Station plugin (Yakumy/Station) has a directional move
   with fallbacks that we want: SHIFT+CTRL+SUPER+arrows tries a normal Hyprland
   move, then the neighbouring display (same group), then the next group at the
   outer edge. That chord is free today.
2. **Blocks follow connector names, and those names are unstable.** Blocks are
   assigned to monitors sorted by connector name. On p620 the two identical
   Razer panels' DP names swap between boots (`monitors.lua` pins them by `desc:`
   for this reason), so 1-10 and 11-20 can trade physical screens. On razer,
   `eDP-1` sorts after `DP-*`/`HDMI-*`, so plugging in any external display moves
   the laptop panel from block 1-10 to 11-20.
3. **Hot-plug is not handled.** Workspace rules are written once at config
   load. If the ARZOPA portable is plugged in later, workspaces 21-30 never
   exist and group switching silently does nothing on it. `SUPER+CTRL+G` after an
   unplug piles every stranded window onto one workspace, losing which group
   each was in.
4. **Stock Omarchy binds fight the groups.** `SUPER+SHIFT+ALT+arrows` moves a
   whole workspace to another monitor (breaking the pinning and making
   `current_group()` fall back to 1); `SUPER+scroll`, `SUPER+SHIFT+TAB` and
   `SUPER+CTRL+TAB` switch one monitor only.
5. **The bar widget does not understand groups.** Omarchy's stock
   `Workspaces.qml` only shows ids 1-10 (line 26), so when DP-3 or the HDMI is
   focused, the active-group dot disappears on every bar, a group whose windows
   are only on screen 2/3 shows as empty, and clicking a number switches only
   the first monitor (it dispatches `hl.dsp.focus({ workspace = id })`).

Items 2-5 came out of the Codex (gpt-6-sol) and agy (model not reported)
second-opinion reviews of this request. Each was checked against the live p620
session: the Workspaces.qml filter and click dispatch exist as quoted, the
SUPER+SHIFT+ALT+arrow binds are live, and `hl.get_monitors()` exposes
`x/y/width/height/description` while windows expose `at/size/floating/fullscreen/pinned`.

## Proposed outcome

- SHIFT+CTRL+SUPER+arrow moves the focused window: within the layout if it can,
  otherwise to the display in that direction (staying in the same group, focus
  following), otherwise at the left/right edge of the desk into the
  previous/next group. Up/down at the outer edge does nothing.
- Each physical screen keeps the same block across reboots and when the
  portable display or a laptop external comes and goes.
- Plugging a display in gives it working groups without a reload; the
  reclaim key returns stranded windows to their own group.
- No stock binding moves a single monitor out of its group.
- The bar shows the current group and occupancy correctly on every screen, and
  clicking a number switches all screens.

## Affected users and systems

- `hosts/common/nixos/omarchy-workspaces.nix` (writes
  `~/.config/hypr/workspace-groups.lua`), imported by p620, razer **and p510**
  (the header comment still says "p620 and razer").
- Omarchy's bar workspace widget (stock, from the nixarchy input).
- p620 (3 screens) gets the most out of it; razer and p510 run the same code
  with one screen, where the directional key degrades to "move, else next
  group".

## Constraints

- Stay in plain Lua in the existing module; no compiled Hyprland plugin and no
  runtime-installed Omarchy plugin (Station itself is not adopted: it writes
  monitors by connector name and would undo p620's `desc:` pinning).
- Top-level code in `workspace-groups.lua` must tolerate the keybindings menu's
  stub `hl` (counted loops, no `ipairs` over `hl.*` results).
- Changing block ownership relocates existing windows the first time; record
  `hyprctl -j clients` before the switch, as in PR #1513.
- p510 is never built or deployed without asking.
- No change to `~/.config/hypr/monitors.lua` (user-owned, pinned by serial).

## Open questions

1. **Scope.** Do all five items go in this task, or only the directional move
   (1) plus the cheap fixes (2, 4)? My recommendation is 1-4 here and the bar
   widget (5) as its own issue, because it means cloning or patching an Omarchy
   QML widget instead of editing Lua.
2. **Block ordering key.** Order by position (row, then column: Codex and agy
   agree) or by panel identity (`desc:`)? Position is generic across hosts but
   depends on the monitor layout already being applied when the file loads.
   Identity is robust but needs a per-host list.
3. **What replaces the conflicting stock binds**: unbind them, or rebind
   SUPER+scroll / SUPER+SHIFT+TAB to group cycling and SUPER+SHIFT+ALT+arrows to
   the new directional window move?
4. **Untested platform facts** that the spec must settle live: whether
   `hl.dispatch` inside a bind updates the window state synchronously (Station
   waits 20 ms and agy says it does not have to), and the exact monitor
   hot-plug event name for `hl.on`.

## Resolution (at approval, 2026-10-14)

Approved with the recommendations: scope is items 1-4; the bar widget (5) is a
separate issue. Block ordering and the replacement for the conflicting binds
are decided in the spec, for review there.
