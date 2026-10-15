# Workspace groups for the Omarchy session, shared by p620, razer and p510.
#
# Hyprland has no workspace that spans monitors: a workspace lives on exactly
# one output, by design. The ecosystem answer is a compiled plugin (hyprsplit,
# split-monitor-workspaces), but both give *independent* per-monitor sets --
# SUPER+1 still moves only the focused display -- and a plugin has to be
# rebuilt against every Hyprland bump, which here would mean pinning
# hyprlandPlugins to pkgs.hyprland forever.
#
# So a "workspace" is a group of real workspaces, one per monitor, switched
# together. HLMonitor:set_workspace retargets a monitor without touching focus,
# which is what makes the displays you are not looking at change underneath you
# while the cursor stays put.
#
# Generic over monitor count, so the same file is right on the single-panel
# hosts razer and p510 (where a group degenerates to a plain workspace) and on
# p620's three.
#
# hyprsplit was reviewed as an alternative (#1517) and cannot replace this: its
# dispatchers are all scoped "on the current monitor", which is the one thing we
# need not to be. Two of its ideas are worth having though, and are implemented
# below: name-ordered blocks (its force_monitor_priority) and a rogue-window
# grab for when a display is unplugged.
#
# Loaded by ~/.config/hypr/bindings.lua with
#   require("hypr.workspace-groups")
# which is the one line that stays hand-written: bindings.lua is where Omarchy
# expects personal edits, so it stays user-owned rather than becoming a store
# symlink.
#
# Omarchy's bar widget only knows ids 1-10, so it is patched to fold ids into
# groups and to switch every display on click (#2306).
{ inputs, pkgs, ... }:
let
  omarchy = (pkgs.extend inputs.nixarchy.overlays.default).omarchy.overrideAttrs (old: {
    # --fuzz=0: an upstream change to the widget fails the build instead of reverting it.
    postInstall = (old.postInstall or "") + ''
      patch -d "$out/share/omarchy" -p1 --forward --fuzz=0 < ${./omarchy-workspaces-bar.patch}
    '';
  });
in
{
  # Built from inputs, never config.programs.nixarchy.package: reading that recurses.
  programs.nixarchy.package = omarchy;
  home-manager.users.olafkfreund.programs.nixarchy.package = omarchy;

  home-manager.users.olafkfreund.home.file.".config/hypr/workspace-groups.lua".text = ''
    -- Managed by hosts/common/nixos/omarchy-workspaces.nix -- edits here are
    -- overwritten on the next deploy.

    local WS_PER_MONITOR = 10

    -- Connector names are unstable (p620's Razers swap DP-n between boots, and
    -- razer's eDP-1 sorts after any external), so order by position, row first,
    -- so that p620's portable below the Razers is always the third block.
    local function ordered_monitors()
      -- Counted, not ipairs: omarchy-menu-keybindings scans this file against
      -- a stub hl whose every index returns a value, so ipairs never ends.
      local all, mons = hl.get_monitors(), {}
      for i = 1, #all do mons[i] = all[i] end
      table.sort(mons, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        if a.x ~= b.x then return a.x < b.x end
        return a.name < b.name
      end)
      return mons
    end

    -- The Nth monitor in that order owns the block (N-1)*10+1 .. N*10, so group G is
    -- workspace G on the first, G+10 on the second, G+20 on the third.
    local function member(index, group)
      return (index - 1) * WS_PER_MONITOR + group
    end

    local function group_of(id)
      return (id - 1) % WS_PER_MONITOR + 1
    end

    local function index_of(target)
      for index, mon in ipairs(ordered_monitors()) do
        if mon.name == target.name then
          return index
        end
      end
    end

    -- The rules have to be persistent: set_workspace silently no-ops on a
    -- workspace that does not exist yet -- it returns "ok" and changes
    -- nothing -- so something must create the whole block up front. Pinning
    -- each block to its own output also stops a click in the bar dragging a
    -- workspace onto the wrong screen.
    local function apply_rules()
      for index, mon in ipairs(ordered_monitors()) do
        for group = 1, WS_PER_MONITOR do
          hl.workspace_rule({
            workspace = tostring(member(index, group)),
            monitor = mon.name,
            persistent = true,
          })
        end
      end
    end
    apply_rules()

    -- Read the current group back off the focused monitor rather than
    -- remembering it, so a bar click or a direct SUPER+N cannot leave the
    -- arrow keys cycling from a stale position.
    local function current_group()
      for _, mon in ipairs(ordered_monitors()) do
        if mon.focused and mon.active_workspace and mon.active_workspace.id >= 1 then
          return group_of(mon.active_workspace.id)
        end
      end
      return 1
    end

    local former_group = 1
    local function focus_group(group)
      local now = current_group()
      if now ~= group then former_group = now end
      for index, mon in ipairs(ordered_monitors()) do
        -- A bare number, not { workspace = n }: HLMonitor:set_workspace wants
        -- "a workspace object or selector" and rejects a table outright, so
        -- every group switch raised a Lua runtime error and the monitors
        -- never moved. Verified against the live compositor with
        -- `hyprctl eval` before changing it.
        mon:set_workspace(member(index, group))
      end
    end

    local function resync()
      apply_rules()
      focus_group(current_group())
    end
    hl.on("monitor.added", resync)
    hl.on("monitor.removed", resync)
    hl.on("monitor.layout_changed", resync)

    local function cycle_group(step)
      focus_group((current_group() - 1 + step) % WS_PER_MONITOR + 1)
    end

    -- Send the window to its *own* monitor's member, so moving a window never
    -- flings it onto a different screen, then bring the other displays along.
    local function move_to_group(group, follow)
      local before = current_group()
      local win = hl.get_active_window()
      local mon = (win and win.monitor) or hl.get_monitor_at_cursor()
      local index = mon and index_of(mon)
      if index then
        hl.dispatch(hl.dsp.window.move({ workspace = member(index, group), follow = follow }))
      end
      focus_group(group)
      if before ~= group then former_group = before end
    end

    -- Omarchy binds the number row by keycode, not by "1".."0", so unbind the
    -- same way or both handlers stay live on the key.
    for group = 1, WS_PER_MONITOR do
      local key = "code:" .. tostring(group + 9)
      hl.unbind("SUPER + " .. key)
      hl.unbind("SUPER + SHIFT + " .. key)
      hl.unbind("SUPER + SHIFT + ALT + " .. key)

      o.bind("SUPER + " .. key, "Workspace " .. group .. " (all displays)", function()
        focus_group(group)
      end)
      o.bind("SUPER + SHIFT + " .. key, "Move window to workspace " .. group, function()
        move_to_group(group, true)
      end)
      o.bind("SUPER + SHIFT + ALT + " .. key, "Move window silently to workspace " .. group, function()
        move_to_group(group, false)
      end)
    end

    -- Unplugging a display leaves its windows on workspaces that no longer
    -- belong to any monitor -- pull the ARZOPA and everything on 21-30 is
    -- unreachable. Sweep them onto the focused monitor, each into its own group.
    -- (hyprsplit calls this grab_rogue_windows.)
    local function grab_rogue_windows()
      local live = #ordered_monitors() * WS_PER_MONITOR
      local active = hl.get_active_window()
      local here = active and active.monitor
      if not here then
        for _, mon in ipairs(ordered_monitors()) do
          if mon.focused then here = mon end
        end
      end
      local index = here and index_of(here)
      if not index then
        return
      end
      for _, win in ipairs(hl.get_windows()) do
        local ws = win.workspace
        -- id < 1 is a special workspace (scratchpad), which is never stranded.
        if ws and ws.id >= 1 and ws.id > live then
          hl.dispatch(hl.dsp.window.move({ window = win, workspace = member(index, group_of(ws.id)), follow = false }))
        end
      end
    end

    local function overlaps(a0, a1, b0, b1) return a0 < b1 and b0 < a1 end

    -- width/height are the panel's mode; positions are logical, so undo scale and rotation.
    local function box(m)
      local w, h = m.width / m.scale, m.height / m.scale
      if m.transform % 2 == 1 then w, h = h, w end
      return m.x, m.y, m.x + w, m.y + h
    end

    -- Hyprland's own rule: beyond our edge in dir, overlapping on the cross axis.
    local function neighbour(cur, dir)
      local best, best_gap
      local x0, y0, x1, y1 = box(cur)
      for _, m in ipairs(ordered_monitors()) do
        local gap
        local a0, b0, a1, b1 = box(m)
        if dir == "l" and a1 <= x0 and overlaps(b0, b1, y0, y1) then gap = x0 - a1
        elseif dir == "r" and a0 >= x1 and overlaps(b0, b1, y0, y1) then gap = a0 - x1
        elseif dir == "u" and b1 <= y0 and overlaps(a0, a1, x0, x1) then gap = y0 - b1
        elseif dir == "d" and b0 >= y1 and overlaps(a0, a1, x0, x1) then gap = b0 - y1
        end
        if gap and (not best_gap or gap < best_gap) then best, best_gap = m, gap end
      end
      return best
    end

    -- The far end of cur's row: leftmost when wrapping right, rightmost when wrapping left.
    local function row_end(cur, dir)
      local pick = cur
      local _, y0, _, y1 = box(cur)
      for _, m in ipairs(ordered_monitors()) do
        local _, b0, _, b1 = box(m)
        if overlaps(b0, b1, y0, y1)
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
        -- send's follow already shows target, so focus_group would not see the group we left.
        former_group = group
        send(after, row_end(mon, dir), target)
        focus_group(target)
      end
    end

    o.bind("SUPER + CTRL + G", "Reclaim windows from unplugged displays", grab_rogue_windows)

    -- Step through the groups. Omarchy ships SUPER+CTRL+LEFT/RIGHT as
    -- "move grouped window focus", which is what these replace.
    hl.unbind("SUPER + CTRL + LEFT")
    hl.unbind("SUPER + CTRL + RIGHT")
    o.bind("SUPER + CTRL + LEFT", "Previous workspace (all displays)", function()
      cycle_group(-1)
    end)
    o.bind("SUPER + CTRL + RIGHT", "Next workspace (all displays)", function()
      cycle_group(1)
    end)

    -- SUPER+SHIFT+ALT+arrows moved a whole workspace to another monitor and broke the pinning.
    for _, arrow in ipairs({ { "LEFT", "l" }, { "RIGHT", "r" }, { "UP", "u" }, { "DOWN", "d" } }) do
      hl.unbind("SUPER + SHIFT + ALT + " .. arrow[1])
      o.bind("SUPER + SHIFT + CTRL + " .. arrow[1], "Move window " .. arrow[1]:lower() .. " (displays and groups)", function()
        move_direction(arrow[2])
      end)
    end

    -- The stock TAB/scroll binds switched one monitor only.
    hl.unbind("SUPER + SHIFT + TAB")
    hl.unbind("SUPER + CTRL + TAB")
    hl.unbind("SUPER + mouse_down")
    hl.unbind("SUPER + mouse_up")
    o.bind("SUPER + SHIFT + TAB", "Previous workspace (all displays)", function() cycle_group(-1) end)
    o.bind("SUPER + CTRL + TAB", "Former workspace (all displays)", function() focus_group(former_group) end)
    o.bind("SUPER + mouse_down", "Next workspace (all displays)", function() cycle_group(1) end)
    o.bind("SUPER + mouse_up", "Previous workspace (all displays)", function() cycle_group(-1) end)

    -- The bar's workspace widget calls this through `hyprctl eval` (#2306).
    WorkspaceGroups = { focus = focus_group }
  '';
}
