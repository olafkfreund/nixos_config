# Hyprland layouts for the Omarchy session on p620 and razer (#2685).
#
# Omarchy's store hyprland.lua requires monitors, input, bindings,
# looknfeel, autostart, then default.hypr.toggles, which replays the
# per-workspace choices SUPER+L saved. Since nixarchy#1598 the store file
# loads layouts.lua itself: after looknfeel, where Atmos writes its own
# layout = "scrolling", and before the saved choices, which still win.
#
# autostart.lua loads Hyprflip and the declared keys (omarchy-keys.nix). force: the nixarchy seed copies
# Omarchy's autostart.lua here with `cp -rn`, so without it home-manager
# refuses to link over it.
{ ... }:
{
  home-manager.users.olafkfreund.home.file = {
    ".config/hypr/autostart.lua" = {
      force = true;
      text = ''
        -- Managed by hosts/common/nixos/omarchy-layouts.nix (#2685).
        -- Extra autostart processes.
        -- o.launch_on_start("my-service")

        -- Hyprflip rotating cards (plugin installed by programs.hyprflip).
        pcall(require, "hypr.hyprflip")

        -- Declared keys from omarchy-keys.nix.
        if package.searchpath("hypr.repo-keys", package.path) then
          local ok, err = pcall(require, "hypr.repo-keys")
          if not ok then
            hl.exec_cmd("omarchy-notification-send " .. o.shell_quote("hypr/repo-keys.lua failed: " .. tostring(err)))
          end
        end
      '';
    };

    ".config/hypr/layouts.lua" = {
      force = true;
      text = ''
        -- Managed by hosts/common/nixos/omarchy-layouts.nix (#2685).
        -- https://wiki.hypr.land/configuring/layouts/
        hl.config({
          general = { layout = "scrolling" },
          -- One big window on the right; new windows stack on the left.
          master = { orientation = "right", mfact = 0.65, new_status = "slave" },
        })

        local dir = require("default.hypr.paths").state_home .. "/omarchy/workspace-layouts"
        local DEFAULT = "scrolling" -- general.layout above
        local NEXT = { scrolling = "master", master = "monocle" }

        local function match(path, pattern)
          local f = io.open(path, "r")
          if not f then
            return nil
          end
          local text = f:read("*a")
          f:close()
          return text and text:match(pattern)
        end

        local function saved_default()
          return match(dir .. "/default.lua", 'default = "(%a+)"')
        end

        local function active()
          local ws = hl.get_active_workspace()
          if ws and ws.id and ws.id >= 1 then
            return ws
          end
        end

        -- As omarchy-hyprland-workspace-layout-current: Omarchy's floating
        -- mode keeps the old tiled layout underneath, so tiled_layout comes last.
        local function mode(ws)
          return match(dir .. "/" .. ws.id .. ".lua", 'mode = "(%a+)"') or saved_default() or ws.tiled_layout
        end

        -- As omarchy-hyprland-workspace-layout-toggle, with master and monocle.
        local function cycle()
          local ws = active()
          if not ws then
            return
          end
          local id = tostring(ws.id)
          local new = NEXT[mode(ws)] or "scrolling"
          local path = dir .. "/" .. id .. ".lua"
          if not pcall(o.workspace_mode, { workspace = id, mode = new }) then
            hl.exec_cmd("omarchy-notification-send 'Workspace layout not changed'")
            return
          end
          local saved
          if new == (saved_default() or DEFAULT) then
            os.remove(path)
            local left = io.open(path, "r")
            saved = left == nil -- gone, or was never there
            if left then
              left:close()
            end
          else
            local f = o.shell_succeeds("mkdir -p " .. o.shell_quote(dir)) and io.open(path, "w")
            saved = f and f:write(string.format('o.workspace_mode({ workspace = "%s", mode = "%s" })\n', id, new)) ~= nil
            saved = (f and f:close() and saved) or false
          end
          if not saved then
            hl.exec_cmd("omarchy-notification-send 'Workspace layout not saved'")
          end
          hl.exec_cmd("omarchy-shell -q omarchy.workspaces refresh")
          hl.exec_cmd("omarchy-shell -q omarchy.dock refresh")
        end

        local function by_layout(messages)
          return function()
            local ws = active()
            -- The saved file only tells floating apart; otherwise trust the live layout.
            local message = ws and mode(ws) ~= "floating" and messages[ws.tiled_layout]
            if message then
              hl.dispatch(hl.dsp.layout(message))
            end
          end
        end

        o.bind("SUPER + SHIFT + L", "Cycle workspace layout: scrolling, master, monocle", cycle)
        o.bind("SUPER + code:34", "Layout: narrower column, smaller main window, previous window", by_layout({
          scrolling = "colresize -conf", master = "mfact -0.05", monocle = "cycleprev",
        }))
        o.bind("SUPER + code:35", "Layout: wider column, bigger main window, next window", by_layout({
          scrolling = "colresize +conf", master = "mfact +0.05", monocle = "cyclenext",
        }))
        o.bind("SUPER + code:51", "Layout: swap column, swap into main window", by_layout({
          scrolling = "swapcol r", master = "swapwithmaster master",
        }))

        -- shortcut: the direction is not saved, so a config reload returns every workspace to horizontal.
        local directions = {}
        o.bind("SUPER + CTRL + SHIFT + L", "Layout: flip scrolling between horizontal and vertical", function()
          local ws = active()
          if not ws or mode(ws) ~= "scrolling" then
            return
          end
          local direction = directions[ws.id] == "down" and "right" or "down"
          directions[ws.id] = direction
          hl.workspace_rule({ workspace = tostring(ws.id), layout_opts = { direction = direction } })
          -- The rule applies at the next re-tile; a zero resize forces one now.
          hl.dispatch(hl.dsp.layout("colresize +0"))
        end)
      '';
    };
  };
}
