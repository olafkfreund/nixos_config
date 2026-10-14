---
status: approved
issue: 2305
intent: intent/2026-10-14-2305-directional-window-move.md
---

# Spec: windows move across displays and groups with one key, and groups stay on the right screen

## Design

Everything stays in the one file `hosts/common/nixos/omarchy-workspaces.nix`
(the Lua it writes to `~/.config/hypr/workspace-groups.lua`), imported by p620,
razer and p510. No new file, module option or plugin.

### Platform facts settled live on p620 (Hyprland 0.56, 2026-10-14)

| Fact | Evidence |
| ---- | -------- |
| A Lua `hl.dispatch(hl.dsp.window.move{...})` takes effect before it returns: the same callback reads the new workspace, monitor and `at`. No 20 ms wait (Station's) is needed. | `hyprctl eval` moved a hidden window 16 → 29 → 16 and read `ws/mon/at` after each move: `16 DP-3 2575`, `29 HDMI-A-1 1609`, `16 DP-3 2575`. |
| Monitors expose `x y width height name description`; windows expose `address at size floating fullscreen pinned workspace monitor`. | `hyprctl eval` field dump. |
| Event names exist: `monitor.added`, `monitor.removed`, `monitor.layout_changed`, `config.reloaded`. | `strings` on the 0.56 binary. |
| `hypr.monitors` is required before `hypr.bindings` in the store `hyprland.lua`, so positions are set when `workspace-groups.lua` loads. | Store `hyprland.lua` lines 19 and 21. |
| `binds:window_direction_monitor_fallback = true`: a native directional move already crosses to the adjacent monitor, but only to one that **overlaps on the cross axis**. | `hyprctl getoption`. |

### 1. Block ordering by position, recomputed on hot-plug

`ordered_monitors()` sorts by `y`, then `x`, then `name`, instead of `name`.
Row first, so on p620 the portable under the two Razers (`1594,1440`) is always
block 3 and never sits between the Razers (an `x`-first sort would renumber the
right Razer whenever the portable is plugged in). Today's p620 order is
unchanged (DP-1 `0,0`, DP-3 `2560,0`, HDMI-A-1 `1594,1440`), so the deploy
moves no windows there.

The rule loop becomes a function, `apply_rules()`, called at load and from
`hl.on("monitor.added" | "monitor.removed" | "monitor.layout_changed", ...)`.
After re-pinning, it calls `focus_group(current_group())` so a newly plugged
display joins the current group.

### 2. Group read from the workspace id, not the monitor index

A helper `group_of(id) = (id - 1) % 10 + 1`. `current_group()` and the new code
use it, so a window or workspace that is displaced to the wrong monitor still
reports its true group (today a displaced ws 1 on monitor 2 computes `-9` and
falls back to 1).

### 3. Directional move: `SUPER + SHIFT + CTRL + arrows`

`move_direction(dir)` for the active window, with `dir` in `l r u d`:

1. No window, a special workspace (`id < 1`), fullscreen (`fullscreen ~= 0`)
   or pinned: dispatch the plain native move and stop. These keep Hyprland's
   own behaviour.
2. Note `group = group_of(ws.id)` and the window's `ws`, `monitor`, `at`, `size`.
   Dispatch the native `hl.dsp.window.move({ direction = dir })`. Re-read the
   window by address.
3. **Moved to another monitor** (Hyprland's own neighbour): if the workspace it
   landed on is not that monitor's member of `group`, move it there with
   `follow = true`. Done.
4. **Moved within the workspace** (`ws`, `at` or `size` changed): done.
5. **No change** (edge of the layout, or a floating window at a screen edge):
   look for a neighbour monitor in `dir` using Hyprland's own rule: its near
   edge lies beyond the current monitor's edge in that direction **and** it
   overlaps on the cross axis; take the nearest. If found, move the window to
   that monitor's member of `group`, `follow = true`.
6. **No neighbour, `dir` is `l` or `r`:** the outer edge. Wrap the group
   (`group ± 1`, wrapping 1↔10 like `SUPER+CTRL+arrows`). Target the monitor at
   the opposite end of the **same row** (cross-axis overlap with the current
   monitor; leftmost when going right, rightmost when going left). Move the
   window to that monitor's member of the new group with `follow = true`, then
   `focus_group(new group)`.
7. **No neighbour, `dir` is `u` or `d`:** nothing.

Worked examples on p620:

| Window on | Key | Result |
| --------- | --- | ------ |
| DP-1, right edge of layout | RIGHT | native crosses to DP-3, member of same group |
| DP-3, right edge | RIGHT | no neighbour → group+1, lands on DP-1 (left end of the top row) |
| HDMI-A-1 | LEFT | no overlap with DP-1 → group−1, lands on HDMI-A-1 itself (only screen in its row) |
| HDMI-A-1 | UP | DP-1 or DP-3 (both overlap; nearest by Hyprland) |
| DP-1 | UP | nothing |

razer and p510 have one screen: steps 3 and 5 never fire, so the key is "move
in the layout, else previous/next group".

### 4. Reclaim keeps the group

`grab_rogue_windows()` (`SUPER+CTRL+G`) moves each stranded window
(`id > #monitors * 10`) to the focused monitor's member of `group_of(id)`,
`follow = false`, instead of piling them all onto the current workspace.

### 5. Stock binds that switch one monitor

| Bind | Stock | Becomes |
| ---- | ----- | ------- |
| `SUPER + SHIFT + ALT + arrows` | move workspace to monitor (breaks pinning) | unbound |
| `SUPER + SHIFT + TAB` | previous workspace on one monitor | previous group |
| `SUPER + CTRL + TAB` | former workspace on one monitor | former group (the group before the last `focus_group`, held in a local) |
| `SUPER + mouse_down / mouse_up` | next/previous workspace on one monitor | next/previous group |

`SUPER + TAB` and `ALT + (SHIFT +) TAB` are already the user's workspace
switcher in `~/.config/hypr/bindings.lua` and are not touched. The header
comment is corrected to say p620, razer and p510.

## Alternatives rejected

- **Adopt the Station plugin.** Writes `monitors.lua` by connector name and
  would undo p620's `desc:` pinning; runtime-installed, so not reproducible
  across hosts; takes the same keys as our groups.
- **Station's 20 ms settle timer.** Measured unnecessary: Lua dispatch is
  synchronous.
- **Station's centre-distance neighbour score (`forward + 2*cross`).** On
  p620's T layout it sends LEFT/RIGHT on the portable diagonally up to a
  Razer. Hyprland's overlap rule is what its own native move already uses, so
  both steps agree.
- **Blocks keyed on panel identity (`desc:`).** Robust, but needs a list per
  host; position gives the right answer on all three hosts today.
- **Fixed, non-compacting blocks (Codex).** Keeps a block for a display that
  is gone; the reclaim key already covers stranded windows.
- **`hyprctl reload` on hot-plug.** Heavier than re-registering rules; kept as
  the fallback if step 1's in-process re-pinning proves not to override the
  earlier rules (see Risks).
- **Group-aware bar widget.** Out of scope per the approved intent; separate
  issue.

## Risks

- **Re-registered workspace rules may not override the earlier ones.**
  Hyprland could keep the load-time rule for a workspace. Plan verifies on
  p620 by re-pinning a hidden workspace live; if the new rule does not win,
  the hot-plug handler issues `hyprctl reload` instead.
- **`hl.on` handlers might stack across config reloads** (every `hyprctl
  reload` re-runs the file). Plan verifies that the count stays at one; if it
  stacks, guard with a global flag.
- **razer with an external display placed left of, or above, the laptop**
  makes the external block 1 and moves the laptop panel's windows to 11-20 on
  first plug. This is the cost of position ordering. Nothing moves on p620
  today.
- **Native directional move on a floating window** nudges it rather than
  crossing at once, so crossing takes a few presses until it reaches the edge.
  Acceptable; matches Hyprland.
- **Keybindings menu scan.** Top-level `hl.on` and the new loops run against
  the stub `hl`; the existing counted-loop pattern applies.
- p510 gets the change through the shared import; it is never built or
  deployed without asking.

## Verification

1. `just check-syntax`, then `just test-host p620` and `just test-host razer`.
   p510 is evaluated only (`nix eval .#nixosConfigurations.p510.config.system.build.toplevel.drvPath`).
2. After deploying p620: `hyprctl -j binds` shows four "Move window …
   (displays and groups)" binds on SUPER+SHIFT+CTRL arrows, no "Move workspace
   to … monitor", and `SUPER+SHIFT+TAB`, `SUPER+CTRL+TAB` and SUPER+scroll
   describe groups.
3. Directional table above, run by hand on p620 (the user presses the keys;
   Hyprland binds cannot be fired with synthetic input here).
4. Hot-plug: unplug and replug the ARZOPA without reloading. SUPER+N then
   switches it, and `hyprctl -j workspaces` shows 21-30 on HDMI-A-1.
5. Reclaim: strand a window on ws 31 (`hl.dsp.window.move{ window = "address:…",
   workspace = 31 }`) and on ws 25, press SUPER+CTRL+G, and check that they land
   on groups 1 and 5.
6. Keybindings menu (Super+K) opens and lists the new binds (stub-`hl` scan
   still terminates).
