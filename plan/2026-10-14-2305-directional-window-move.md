---
status: draft
issue: 2305
spec: spec/2026-10-14-2305-directional-window-move.md
---

# Plan: windows move across displays and groups with one key, and groups stay on the right screen

## Summary of approved decisions

All edits go in **one file**, `hosts/common/nixos/omarchy-workspaces.nix`. It
writes `~/.config/hypr/workspace-groups.lua` as a Nix `''…''` string
(Home Manager `home.file.<…>.text`) and is imported by p620, razer and p510. A
"group" N is workspace N on the 1st monitor, N+10 on the 2nd and N+20 on the
3rd; `WS_PER_MONITOR = 10`; `member(index, group) = (index-1)*10 + group`.

1. Order monitors by `y`, then `x`, then `name` (not by name). Re-apply the
   workspace rules on `monitor.added`, `monitor.removed` and
   `monitor.layout_changed`, then re-sync the current group.
2. `group_of(id) = (id - 1) % 10 + 1` is the group of any workspace id.
   `current_group()` uses it.
3. New `SUPER + SHIFT + CTRL + LEFT/RIGHT/UP/DOWN`: a directional window move.
   It tries Hyprland's native move first, then the neighbouring monitor (same
   group), then, at the left/right outer edge, the previous/next group on the
   opposite end of the same row. Up/down at the edge does nothing. Special,
   fullscreen and pinned windows get only the native move.
4. `SUPER+CTRL+G` sends each stranded window to the focused monitor's member
   of **its own** group.
5. Unbind `SUPER + SHIFT + ALT + arrows`. Rebind `SUPER + SHIFT + TAB` to the
   previous group, `SUPER + CTRL + TAB` to the former group and
   `SUPER + mouse_down/mouse_up` to the next/previous group.

### Live facts already verified on p620 (Hyprland 0.56, 2026-10-14). Do not re-derive these

- `hl.dispatch(hl.dsp.window.move{…})` is synchronous inside Lua: re-reading the
  window in the same callback shows the new `workspace.id`, `monitor.name` and
  `at`.
- Monitor fields: `x y width height name focused active_workspace`. Window
  fields: `address at size floating fullscreen pinned workspace monitor`.
  `at` and `size` are tables with **`.x` / `.y`**, not `[1]`/`[2]`.
  `fullscreen` is a number (0 = not fullscreen).
- `hl.on` is a function. Event names: `monitor.added`, `monitor.removed`,
  `monitor.layout_changed`.
- A workspace rule registered again **overrides the earlier one and applies
  to an existing workspace immediately** (ws 29 was moved to DP-1 and back by
  re-registering). No `hyprctl reload` is needed.
- Native directional move: `hl.dsp.window.move({ direction = "l" })` (`l r u
  d`). `binds:window_direction_monitor_fallback = true`, so it crosses to an
  adjacent monitor only if that monitor overlaps on the cross axis.
- `hyprctl dispatch` / `hyprctl eval` take **Lua**, not classic dispatcher
  strings.

## Steps

1. **`omarchy-workspaces.nix:1, 15-16` (header comment)**: change "shared by
   p620 and razer" to "shared by p620, razer and p510". In the paragraph at
   15-16, say the single-panel case covers razer and p510.
   → verify: `grep -n p510 hosts/common/nixos/omarchy-workspaces.nix`
   Traps: comments stay minimal (no narration); keep them to the why.

2. **`:37-50` `ordered_monitors()`**: sort by
   `a.y ~= b.y → a.y < b.y`, else `a.x ~= b.x → a.x < b.x`, else
   `a.name < b.name`. Replace the comment at 37-42 with two lines: connector
   names are unstable (p620's Razers swap DP-n between boots, and razer's
   `eDP-1` sorts after any external), so order by position, row first, so that
   p620's portable below the Razers is always the third block. Keep the
   counted-loop copy at 46-47 unchanged.
   → verify: `hyprctl eval` is not needed; checked in Tests §2.
   Traps: **never `ipairs` over an `hl.*` result at top level**. The
   keybindings menu (`omarchy-menu-keybindings`) scans this file against a stub
   `hl` where `ipairs` never ends (Issue #2138). `ipairs(ordered_monitors())`
   is fine because it is a plain table built by a counted loop.

3. **`:51-79` rules → `apply_rules()` + events**: add, right after `member`,

   ```lua
   local function group_of(id)
     return (id - 1) % WS_PER_MONITOR + 1
   end
   ```

   Wrap the rule loop at 71-79 in `local function apply_rules() … end` and call
   `apply_rules()` once at top level where the loop was. After
   `focus_group`/`current_group` are defined (they are needed by the handler),
   register:

   ```lua
   local function resync()
     apply_rules()
     focus_group(current_group())
   end
   hl.on("monitor.added", resync)
   hl.on("monitor.removed", resync)
   hl.on("monitor.layout_changed", resync)
   ```

   Keep the existing 66-70 comment above `apply_rules`.
   → verify: Tests §4 (hot-plug) and §5 (handler count).
   Traps: `hl.on` runs at top level under the stub `hl` too. That is fine
   because it only calls a stub. Do **not** add a `_G` "already registered"
   guard pre-emptively; Tests §5 decides it (see the deviation rule there).

4. **`:81-109` `focus_group`, `current_group`, former group**:
   - `current_group()`: return `group_of(mon.active_workspace.id)` for the
     focused monitor when the id is `>= 1`, else `1`. Drop the
     `(index - 1) * WS_PER_MONITOR` arithmetic and its range check, because a
     displaced workspace still reports its true group.
   - Add `local former_group = 1` above `focus_group`. In `focus_group(group)`,
     first `local now = current_group()`, and `if now ~= group then
     former_group = now end`, then the existing loop.
   → verify: `nix eval` in Tests §1; behaviour in Tests §3.
   Traps: `mon:set_workspace(n)` takes a **bare number**, not a table (the
   existing comment at 83-87 records this; keep it).

5. **`:146-159` `grab_rogue_windows()`**: replace `here` (active workspace)
   with the focused monitor's block index. Use `hl.get_active_window()`'s
   monitor if there is a window, else the `focused` entry of
   `ordered_monitors()`, then `index_of(mon)`. Move each stranded window to
   `member(index, group_of(ws.id))`, `follow = false`. Keep the `ws.id >= 1`
   special-workspace guard and its comment. Change the comment at 140-145 to
   say each window returns to its own group.
   → verify: Tests §6.
   Traps: none beyond the stub-`hl` rule.

6. **New `move_direction(dir)` before the bind section (after
   `grab_rogue_windows`)**: implement exactly this:

   ```lua
   local function overlaps(a0, a1, b0, b1) return a0 < b1 and b0 < a1 end

   -- Hyprland's own rule: beyond our edge in dir, overlapping on the cross axis.
   local function neighbour(cur, dir)
     local best, best_gap
     for _, m in ipairs(ordered_monitors()) do
       local gap
       if dir == "l" and m.x + m.width <= cur.x and overlaps(m.y, m.y + m.height, cur.y, cur.y + cur.height) then gap = cur.x - (m.x + m.width)
       elseif dir == "r" and m.x >= cur.x + cur.width and overlaps(m.y, m.y + m.height, cur.y, cur.y + cur.height) then gap = m.x - (cur.x + cur.width)
       elseif dir == "u" and m.y + m.height <= cur.y and overlaps(m.x, m.x + m.width, cur.x, cur.x + cur.width) then gap = cur.y - (m.y + m.height)
       elseif dir == "d" and m.y >= cur.y + cur.height and overlaps(m.x, m.x + m.width, cur.x, cur.x + cur.width) then gap = m.y - (cur.y + cur.height)
       end
       if gap and (not best_gap or gap < best_gap) then best, best_gap = m, gap end
     end
     return best
   end

   -- The far end of cur's row: leftmost when wrapping right, rightmost when wrapping left.
   local function row_end(cur, dir)
     local pick = cur
     for _, m in ipairs(ordered_monitors()) do
       if overlaps(m.y, m.y + m.height, cur.y, cur.y + cur.height)
         and ((dir == "r" and m.x < pick.x) or (dir == "l" and m.x > pick.x)) then
         pick = m
       end
     end
     return pick
   end

   local function find_window(address)
     for _, w in ipairs(hl.get_windows()) do
       if w.address == address then return w end
     end
   end

   local function send(win, mon, group)
     hl.dispatch(hl.dsp.window.move({ window = "address:" .. win.address, workspace = member(index_of(mon), group), follow = true }))
   end

   local function move_direction(dir)
     local win = hl.get_active_window()
     local native = hl.dsp.window.move({ direction = dir })
     if not win or not win.workspace or win.workspace.id < 1 or win.fullscreen ~= 0 or win.pinned then
       hl.dispatch(native)
       return
     end
     local group, ws, mon = group_of(win.workspace.id), win.workspace.id, win.monitor
     local x, y, w, h = win.at.x, win.at.y, win.size.x, win.size.y
     hl.dispatch(native)
     local after = find_window(win.address)
     if not after then return end
     if after.monitor.name ~= mon.name then
       if after.workspace.id ~= member(index_of(after.monitor), group) then send(after, after.monitor, group) end
       return
     end
     if after.workspace.id ~= ws or after.at.x ~= x or after.at.y ~= y or after.size.x ~= w or after.size.y ~= h then
       return
     end
     local next_mon = neighbour(mon, dir)
     if next_mon then
       send(after, next_mon, group)
     elseif dir == "l" or dir == "r" then
       local target = (group - 1 + (dir == "r" and 1 or -1)) % WS_PER_MONITOR + 1
       send(after, row_end(mon, dir), target)
       focus_group(target)
     end
   end
   ```

   `index_of(target)` already exists (`:58-64`) and matches by `name`, so
   passing `win.monitor` or an `ordered_monitors()` entry both work.
   → verify: `nix eval` in Tests §1; behaviour in Tests §3.
   Traps: `win.monitor` is an `HL.Monitor` with `x y width height name`, the
   same as `hl.get_monitors()` entries. Use `"address:" .. addr` as the window
   selector (as in the existing memory note); passing the window object also
   works (line 156 today) but the string form is what the move-by-address test
   proved. Keep the Lua inside the Nix `''` string free of `''` and `${`
   (Nix string escapes).

7. **Bind section (`:161-172` and after)**: add

   ```lua
   for _, arrow in ipairs({ { "LEFT", "l" }, { "RIGHT", "r" }, { "UP", "u" }, { "DOWN", "d" } }) do
     hl.unbind("SUPER + SHIFT + ALT + " .. arrow[1])
     o.bind("SUPER + SHIFT + CTRL + " .. arrow[1], "Move window " .. arrow[1]:lower() .. " (displays and groups)", function()
       move_direction(arrow[2])
     end)
   end

   hl.unbind("SUPER + SHIFT + TAB")
   hl.unbind("SUPER + CTRL + TAB")
   hl.unbind("SUPER + mouse_down")
   hl.unbind("SUPER + mouse_up")
   o.bind("SUPER + SHIFT + TAB", "Previous workspace (all displays)", function() cycle_group(-1) end)
   o.bind("SUPER + CTRL + TAB", "Former workspace (all displays)", function() focus_group(former_group) end)
   o.bind("SUPER + mouse_down", "Next workspace (all displays)", function() cycle_group(1) end)
   o.bind("SUPER + mouse_up", "Previous workspace (all displays)", function() cycle_group(-1) end)
   ```

   Add a one-line comment for each block: SUPER+SHIFT+ALT+arrows moved a whole
   workspace to another monitor and broke the pinning; the TAB/scroll binds
   switched one monitor only.
   → verify: Tests §2.
   Traps: `ipairs` over a **literal** table is fine for the stub scan. Do not
   touch `SUPER + TAB` or `ALT (+ SHIFT) + TAB`: they are the user's workspace
   switcher in the user-owned `~/.config/hypr/bindings.lua`. Omarchy's stock
   `SUPER + mouse_down` is spelled exactly that way (`tiling.lua:67-68`).

8. **Commit and PR**: one commit `feat(hypr): directional window move and
   multi-monitor fixes (#2305)` (body via `-F -` heredoc, **no backticks in a
   `-m`**). Open the PR linking intent, spec and plan, and say which steps the
   coder did.

## Tests

1. **Eval/build** (worktree):

   ```bash
   just check-syntax
   just test-host p620
   just test-host razer
   nix eval .#nixosConfigurations.p510.config.system.build.toplevel.drvPath
   ```

   p510 is **evaluated only**, never built or deployed without asking. Use
   `set -o pipefail` if piping a build through `tail`.
   Also lint the generated Lua: build the HM file and run
   `luac -p` (or `lua -e 'loadfile(...)'`) on it.
2. **After deploying p620** (announce on the agent bus first. The guard
   requires it, and the deploy is the user's call; branch deploys need
   `ALLOW_BRANCH_DEPLOY=1` and main merged in first):
   `hyprctl -j binds | jq -r '.[].description' | grep -E "displays and groups|all displays"`
   shows the 4 move binds plus the group TAB/scroll binds, and
   `grep -c "Move workspace to .* monitor"` is 0.
3. **Directional move, by hand on p620** (the user presses the keys):

   | Window on | Key | Expect |
   | --------- | --- | ------ |
   | DP-1, rightmost column | S+C+Super+RIGHT | on DP-3, same group |
   | DP-3, rightmost column | S+C+Super+RIGHT | group+1, on DP-1 |
   | HDMI-A-1 | S+C+Super+LEFT | group−1, stays on HDMI-A-1 |
   | HDMI-A-1 | S+C+Super+UP | on a Razer, same group |
   | DP-1 | S+C+Super+UP | nothing |
   | inside a 2-column workspace | S+C+Super+LEFT | swaps within the workspace only |

4. **Hot-plug**: unplug and replug the ARZOPA without reloading;
   `hyprctl -j workspaces | jq -r '.[] | "\(.id) \(.monitor)"' | sort -n` shows
   21-30 on HDMI-A-1, and SUPER+N switches it.
5. **Handler count after a reload**: `hyprctl reload`, then plug/unplug once
   and count the resyncs: temporarily add
   `hl.dispatch(hl.dsp.exec_cmd("logger -t ws-resync fired"))` to `resync()`
   and count lines in `journalctl -t ws-resync --since -5min`. Remove the line
   afterwards. **Deviation rule:** if the
   count grows with each reload, add a `_G.ws_groups_hooked` guard around the
   three `hl.on` calls, and record it in this plan in the same commit.
6. **Reclaim**: strand two windows
   (`hyprctl dispatch 'hl.dispatch(hl.dsp.window.move({ window = "address:0x…", workspace = 31, follow = false }))'`,
   and another to 35 with the ARZOPA unplugged), press SUPER+CTRL+G: they land
   on the focused monitor's members of groups 1 and 5.
7. Super+K (keybindings menu) opens and lists the new binds.

## Rollback

`git revert` the feature commit and redeploy p620 (and razer). The file is
fully Nix-managed (`home.file.text`), so the previous `workspace-groups.lua`
returns with it. Nothing outside it changes: `bindings.lua`, `monitors.lua`
and Omarchy's defaults are untouched, and unbinds disappear with the file.
