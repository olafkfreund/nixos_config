---
status: approved
issue: 2685
intent: intent/2026-11-04-2685-hyprland-layouts.md
---

# Spec: declarative Hyprland layouts, scrolling default, master-right

## Design

One new shared file, `hosts/common/nixos/omarchy-layouts.nix`. It follows the
`omarchy-input.nix` pattern: a Home Manager `home.file` with `force = true`.
p620 and razer import it from `hosts/<host>/nixos/nixarchy.nix`, next to
`omarchy-input.nix`. p510 does not import it.

It writes two files.

### 1. `~/.config/hypr/layouts.lua` (new)

```lua
-- Managed by hosts/common/nixos/omarchy-layouts.nix (#2685).
hl.config({
  general = { layout = "scrolling" },
  master = { orientation = "right", mfact = 0.65, new_status = "slave" },
})
```

- **`general.layout = "scrolling"`** is the default for every workspace with
  no saved choice, on both hosts.
- **`master`**: the big window goes on the right at 65% of the width, the
  stack in a column on the left. `new_status = "slave"` puts a new window in
  the stack, so the big window stays put. Omarchy's own value, `"master"`,
  would make each new window the big one. `mfact` is only the starting
  share: Omarchy's resize keys and the keys below still change it.
- **Dwindle and scrolling values that equal Omarchy's defaults are not
  restated.** Monocle has no options.

The same file defines the keys. They are Lua functions bound with
`o.bind(keys, description, function)`, as Omarchy's own `utilities.lua:134`
does. They are bound by keycode, as Omarchy binds `code:34`/`code:35`, so they
don't depend on the keyboard layout.

**The current mode** is read the way `omarchy-hyprland-workspace-layout-current`
reads it, because Omarchy's floating mode keeps the workspace's old tiled
layout underneath (`workspace-modes.lua:396`), so `tiled_layout` alone would
call a floating workspace "scrolling" or "master". In order, the mode is:

1. `mode = "<x>"` from `$XDG_STATE_HOME/omarchy/workspace-layouts/<id>.lua`
2. otherwise `default = "<x>"` from `workspace-layouts/default.lua`
3. otherwise `hl.get_active_workspace().tiled_layout` (checked live on p620:
   it returns `dwindle` on workspace 1)

**The default** is read the way `omarchy-hyprland-workspace-layout-default`
reads it: `default.lua` if it exists, otherwise the `general.layout` this file
sets, `scrolling`.

| Key (keycode; gb label) | scrolling | master | monocle | floating |
|---|---|---|---|---|
| SUPER+SHIFT+L | to master | to monocle | to scrolling | to scrolling |
| SUPER+`code:34` (`[`) | `colresize -conf` | `mfact -0.05` | `cycleprev` | nothing |
| SUPER+`code:35` (`]`) | `colresize +conf` | `mfact +0.05` | `cyclenext` | nothing |
| SUPER+`code:51` (`#`, `\` on US) | `swapcol r` | `swapwithmaster master` | nothing | nothing |

On dwindle, SUPER+SHIFT+L goes to scrolling and the other three keys do
nothing.

- **How the cycle key saves a choice.** It does what Omarchy's
  `omarchy-hyprland-workspace-layout-toggle` does:
  - it calls `o.workspace_mode({ workspace = "<id>", mode = "<new>" })`, which
    sets the workspace rule and undoes floating mode
  - if the new mode equals the default read above, it removes `<id>.lua` so
    the workspace follows the default again; otherwise it writes that same
    line to `<id>.lua`
  - if the call or the file write fails, it sends an Omarchy notification
    saying the layout was not saved, as the toggle does
  - it refreshes the bar and the dock with
    `omarchy-shell -q omarchy.workspaces refresh` and
    `omarchy-shell -q omarchy.dock refresh`. The dock shows only on floating
    workspaces, so leaving floating mode needs its refresh.

  Omarchy's restore at login replays these files. `workspace-modes.lua:399`
  passes any non-floating mode name straight to `hl.workspace_rule`, so
  master and monocle survive a reload.
- **Workspaces it skips.** Named and special workspaces (id < 1) are left
  alone, as the toggle leaves them.
- **Free keys.** SUPER+SHIFT+L and SUPER+`code:34`/`35`/`51` are free:
  - not bound by Omarchy's `default/hypr/bindings/*.lua`, which binds only
    SUPER+ALT+34/35, for the webcam overlay
  - not bound by any `~/.config/hypr/*.lua` on p620 or razer (checked)
- **Keybindings menu.** Each key gets a description, so SUPER+K lists it.
  Running a function bind from the menu needs an `o.bind_expressions` entry;
  that is not added, because the user runs these from the keyboard.

### 2. `~/.config/hypr/autostart.lua` (taken over)

Omarchy's store `hyprland.lua` requires its user files in a fixed order:

```text
monitors → input → bindings → looknfeel → autostart → toggles
```

That order decides where `layouts.lua` must load from:

- **After `looknfeel`.** That is where the Atmos block sets
  `layout = "scrolling"` on p620, and anything later wins over it.
- **Before `toggles`.** That restores the saved per-workspace choices, which
  must still win over the default (intent decision: keep them).

`autostart.lua` is the only user file in that slot. Its content on p620 is
Omarchy's two comment lines and `pcall(require, "hypr.hyprflip")`; on razer,
the comment lines only. The managed version keeps all of these and adds one
line:

```lua
pcall(require, "hypr.layouts") -- managed by NixOS (#2685)
```

`pcall` matches every other optional require in these files, so a broken or
missing `layouts.lua` cannot stop the session from loading. It also hides
the error. Verification therefore checks the loaded settings and the four
keys on both hosts, not just the config error list.

## Alternatives rejected

- **Load from `bindings.lua`**, like the `*-binds.lua` files. It loads before
  `looknfeel`, so Atmos's `layout = "scrolling"` would override whatever we
  declare. It is also hand-edited, so it isn't declarative.
- **Append the require to `looknfeel.lua`.** That file is Atmos's: Home Manager
  owning it would make it read-only for Atmos. An activation script editing
  it would be imperative and fragile.
- **Write `workspace-layouts/default.lua`** (Omarchy's
  Appearance > Workspace Layout). It is per-user state, not config, and the
  menu rewrites it. Declaring the default in config leaves the menu as the
  user's runtime override.
- **Fixed per-workspace layout rules in Nix.** Saved choices replay after
  them and win, so the two would fight. None are declared.
- **Patch Omarchy's toggle so SUPER+L cycles master and monocle.** That is
  the nixarchy follow-up. A local patch to the Omarchy tree would be
  overwritten on every nixarchy bump.
- **A shell script for the cycle key**, like the toggle. It needs a packaged
  script and a `hyprctl eval` round trip. A Lua function reads the state
  files and `tiled_layout` directly in a few lines.

## Risks

- **Hand edits to `autostart.lua` are lost** on both hosts. The only edit
  today is the hyprflip line, and the managed file keeps it. Home Manager's
  `force = true` replaces the seeded file without a backup.
- **Bar icon.** Omarchy's workspace widget (`Workspaces.qml:138`) draws a
  square for every mode except scrolling and floating, so master and monocle
  show the dwindle square. Clicking the icon runs Omarchy's toggle, which
  moves the workspace to dwindle. This is cosmetic; the nixarchy follow-up
  can add icons.
- **SUPER+L on a master or monocle workspace** goes to dwindle and saves that
  choice, as the intent accepts.
- **The Appearance menu's default still wins** over `general.layout`, if it
  is ever used, because `default.lua` loads later. That is the menu doing its
  job; neither host has the file today.
- **razer changes default layout**, from dwindle to scrolling. Its saved
  choices (workspaces 1, 2, 6, 24) are all already scrolling, in Omarchy's
  older `hl.workspace_rule` form. The cycle key's mode read doesn't parse that
  form, so on those workspaces it falls back to `tiled_layout`, which is
  `scrolling` and correct.
- **Hyprland 0.57's Lua API has no version-pinned docs.**
  - **Known:** `tiled_layout` was checked live on p620.
  - **Unchecked:** the `layoutmsg` strings (`colresize`, `swapcol`, `mfact`,
    `swapwithmaster`, `cyclenext`) come from the wiki, so a wrong one fails
    on its own key at runtime, not at build time. Verification covers each.

## Verification

1. **Builds.** `just check-syntax`, then `just test-host p620` and
   `just test-host razer` build.
2. **Files are generated correctly.** Both generated files are in the built
   HM files, and `luac -p` (from the `lua` package) parses each one. This
   checks syntax only; steps 3 and 6 prove the file actually ran.
3. **Live on p620, after the switch and a `hyprctl reload`:**
   - `hyprctl getoption general:layout` prints `scrolling`
   - `master:orientation` prints `right`, `master:mfact` prints `0.65` and
     `master:new_status` prints `slave`
   - `hyprctl binds -j` lists all four keys with their descriptions
4. **Behaviour, on an empty workspace on p620 with 3 terminals:**
   - SUPER+SHIFT+L → master: one large window on the right, two stacked on
     the left. A 4th window joins the left stack.
   - In master: SUPER+[ and SUPER+] resize, and SUPER+# swaps into the big
     slot.
   - SUPER+SHIFT+L → monocle: SUPER+[ and SUPER+] cycle windows.
   - SUPER+SHIFT+L → scrolling: the workspace's saved file is gone. SUPER+[
     and SUPER+] resize columns, and SUPER+# swaps columns.
   - Set master, then `hyprctl reload`: the workspace comes back in master.
   - From dwindle (SUPER+L), SUPER+SHIFT+L goes to scrolling.
   - From floating (SUPER+L twice from scrolling), SUPER+SHIFT+L goes to
     scrolling, the windows tile, and the dock hides.
5. **Saved choices kept.** p620's saved files for workspaces 1, 3, 4, 5, 13,
   14 and 22 are unchanged (checksums taken before and after the switch).
6. **razer, after it is rolled out via p620:** checks 3 and 5 for razer's own
   files.
7. **No new errors.** `hyprctl configerrors` is empty on both hosts.
