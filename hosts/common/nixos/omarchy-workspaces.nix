# Workspace groups for the Omarchy session, shared by p620 and razer.
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
# Generic over monitor count, so the same file is right on razer's single
# panel (where a group degenerates to a plain workspace) and on p620's three.
#
# Loaded by ~/.config/hypr/bindings.lua with
#   require("hypr.workspace-groups")
# which is the one line that stays hand-written: bindings.lua is where Omarchy
# expects personal edits, so it stays user-owned rather than becoming a store
# symlink.
{ ... }:
{
  home-manager.users.olafkfreund.home.file.".config/hypr/workspace-groups.lua".text = ''
    -- Managed by hosts/common/nixos/omarchy-workspaces.nix -- edits here are
    -- overwritten on the next deploy.

    local WS_PER_MONITOR = 10

    -- Monitor id N owns the block N*10+1 .. N*10+10, so group G is workspace
    -- G on the first monitor, G+10 on the second, G+20 on the third.
    local function member(mon, group)
      return mon.id * WS_PER_MONITOR + group
    end

    -- The rules have to be persistent: set_workspace silently no-ops on a
    -- workspace that does not exist yet -- it returns "ok" and changes
    -- nothing -- so something must create the whole block up front. Pinning
    -- each block to its own output also stops a click in the bar dragging a
    -- workspace onto the wrong screen.
    for _, mon in ipairs(hl.get_monitors()) do
      for group = 1, WS_PER_MONITOR do
        hl.workspace_rule({
          workspace = tostring(member(mon, group)),
          monitor = mon.name,
          persistent = true,
        })
      end
    end

    local function focus_group(group)
      for _, mon in ipairs(hl.get_monitors()) do
        mon:set_workspace({ workspace = member(mon, group) })
      end
    end

    -- Read the current group back off the focused monitor rather than
    -- remembering it, so a bar click or a direct SUPER+N cannot leave the
    -- arrow keys cycling from a stale position.
    local function current_group()
      for _, mon in ipairs(hl.get_monitors()) do
        if mon.focused and mon.active_workspace then
          local group = mon.active_workspace.id - mon.id * WS_PER_MONITOR
          if group >= 1 and group <= WS_PER_MONITOR then
            return group
          end
        end
      end
      return 1
    end

    local function cycle_group(step)
      focus_group((current_group() - 1 + step) % WS_PER_MONITOR + 1)
    end

    -- Send the window to its *own* monitor's member, so moving a window never
    -- flings it onto a different screen, then bring the other displays along.
    local function move_to_group(group, follow)
      local win = hl.get_active_window()
      local mon = (win and win.monitor) or hl.get_monitor_at_cursor()
      if mon then
        hl.dispatch(hl.dsp.window.move({ workspace = member(mon, group), follow = follow }))
      end
      focus_group(group)
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
  '';
}
