---
status: approved
issue: 2685
spec: spec/2026-11-04-2685-hyprland-layouts.md
coders:
  1: codex # small, tricky Lua: mode detection, state-file persistence, layout-aware dispatch
  2: coder # two one-line imports
  3: coder # one short docs section
reviewers:
  - codex # second read of the Lua state logic against Omarchy's toggle
  - agy # independent read of the load order and key choices
---

# Plan: declarative Hyprland layouts, scrolling default, master-right

## Approved decisions

These come from the spec and must all hold:

- **One new file**, `hosts/common/nixos/omarchy-layouts.nix`, imported by p620
  and razer only, never p510. It writes two Home Manager files, both with
  `force = true`, following the `hosts/common/nixos/omarchy-input.nix`
  pattern.
- **`~/.config/hypr/layouts.lua`** holds:
  - `general.layout = "scrolling"`
  - `master = { orientation = "right", mfact = 0.65, new_status = "slave" }`
  - four keys
  - nothing that restates Omarchy's dwindle or scrolling defaults
- **`~/.config/hypr/autostart.lua`** is taken over. It keeps p620's current
  content (two comment lines and `pcall(require, "hypr.hyprflip")`) and adds
  `pcall(require, "hypr.layouts")`. It loads after `looknfeel` (Atmos) and
  before the saved SUPER+L choices (`default.hypr.toggles`), so the saved
  choices still win. Nothing is cleared.
- **How a workspace's mode is read** matches
  `omarchy-hyprland-workspace-layout-current`, in this order:
  1. `mode = "<x>"` in `$XDG_STATE_HOME/omarchy/workspace-layouts/<id>.lua`
  2. else `default = "<x>"` in `workspace-layouts/default.lua`
  3. else `hl.get_active_workspace().tiled_layout`
- **The default** is `default.lua`'s value if that file exists, else
  `scrolling`.
- **The keys**, bound by keycode:

  | Key | scrolling | master | monocle | dwindle / floating |
  |---|---|---|---|---|
  | SUPER+SHIFT+L | → master | → monocle | → scrolling | → scrolling |
  | SUPER+code:34 | `colresize -conf` | `mfact -0.05` | `cycleprev` | nothing |
  | SUPER+code:35 | `colresize +conf` | `mfact +0.05` | `cyclenext` | nothing |
  | SUPER+code:51 | `swapcol r` | `swapwithmaster master` | nothing | nothing |

- **The cycle key mirrors Omarchy's toggle.** It calls
  `o.workspace_mode({ workspace = id, mode = new })`. If `new` is the
  default, it removes `<id>.lua`; otherwise it writes that same line there.
  On failure it notifies "not saved". It then refreshes the bar and the dock
  with `omarchy-shell -q omarchy.workspaces refresh` and
  `omarchy-shell -q omarchy.dock refresh`. Workspaces with id < 1 are
  skipped.
- **SUPER+L is unchanged.** Running a key from the SUPER+K menu is not
  supported (no `o.bind_expressions` entry).

## Steps

1. **New `hosts/common/nixos/omarchy-layouts.nix`** (coders: codex). Write the
   file below exactly, adjusting only if a check fails; record any
   adjustment here.

   ```nix
   # Hyprland layouts for the Omarchy session on p620 and razer (#2685).
   #
   # Omarchy's store hyprland.lua requires monitors, input, bindings,
   # looknfeel, autostart, then default.hypr.toggles, which replays the
   # per-workspace choices SUPER+L saved. layouts.lua is required from
   # autostart.lua: after looknfeel, where Atmos writes its own
   # layout = "scrolling", and before the saved choices, which still win.
   #
   # force: the nixarchy seed copies Omarchy's autostart.lua here with
   # `cp -rn`, so without it home-manager refuses to link over it.
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

           pcall(require, "hypr.layouts")
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
               saved = io.open(path, "r") == nil -- gone, or was never there
             else
               local f = os.execute("mkdir -p " .. o.shell_quote(dir)) and io.open(path, "w")
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
               local message = ws and messages[mode(ws)]
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
         '';
       };
     };
   }
   ```

   **Verify:**
   - `nix-instantiate --parse hosts/common/nixos/omarchy-layouts.nix >/dev/null`
   - Render both files and parse them:

     ```bash
     for f in autostart layouts; do
       nix eval --raw --impure --expr "(import ./hosts/common/nixos/omarchy-layouts.nix {}).home-manager.users.olafkfreund.home.file.\".config/hypr/$f.lua\".text" > "$TMPDIR/$f.lua"
       nix shell nixpkgs#lua5_4 -c luac -p "$TMPDIR/$f.lua" && echo "$f ok"
     done
     ```

   **Traps:**
   - Nix `''` strings: no `${` in the Lua (there is none), and `''` must not
     appear inside it.
   - `o` is Omarchy's global (`helpers.lua:5`). `o.workspace_mode` comes from
     `default.hypr.workspace-modes`, which is first required by
     `workspace-layouts.lua` after this file loads, so it is referenced only
     inside `cycle()`, at key-press time.
   - Hyprland embeds Lua 5.5 (checked live), which keeps `io` and `os`.
     `f:read("*a")` is still accepted there.
   - The Hyprland 0.57 `layoutmsg` strings are not checked at build time;
     step 6 exercises each key.
   - Comments only for the why (repo rule: minimal comments).
   - Never `git checkout` in `~/.config/nixos`; work in the
     `~/.config/nixos-2685` worktree.

2. **Imports in `hosts/p620/nixos/nixarchy.nix:27` and
   `hosts/razer/nixos/nixarchy.nix:27`** (coders: coder). In each file, add
   `../../common/nixos/omarchy-layouts.nix` to `imports` on the line after
   `../../common/nixos/omarchy-input.nix`. Do not touch
   `hosts/p510/nixos/nixarchy.nix`.

   **Verify:** `just check-syntax`.

   **Traps:**
   - Explicit imports only (no `readDir`).
   - p510 must not import it.

3. **Docs in `docs/architecture/desktop.md`** (coders: coder). After the
   "Configuration is Lua, not hyprlang" section (line 83 onwards), add
   `## Layouts` in about 12 lines:
   - the default is scrolling, set in `omarchy-layouts.nix`
   - why it loads from `autostart.lua`: after Atmos's `looknfeel`, before
     the saved SUPER+L choices, which still win
   - the four keys, as a table
   - SUPER+L still cycles dwindle, scrolling and floating only. On master or
     monocle it goes to dwindle, and the bar shows the dwindle square for
     both.
   - the nixarchy follow-up

   **Verify:** `nix shell nixpkgs#markdownlint-cli -c markdownlint
   docs/architecture/desktop.md` reports nothing new.

   **Traps:**
   - The pre-push hook lints the whole file.
   - No nav change, so `mkdocs.yml` and `mkdocs-full.yml` stay as they are.

4. **Build** (Claude). Run `just check-syntax`, `just test-host p620` and
   `just test-host razer`. Then check the built copies:

   ```bash
   set -o pipefail
   for h in p620 razer; do
     hm=$(nix build --no-link --print-out-paths ".#nixosConfigurations.$h.config.home-manager.users.olafkfreund.home-files")
     for f in autostart layouts; do
       nix shell nixpkgs#lua5_4 -c luac -p "$hm/.config/hypr/$f.lua" && echo "$h $f ok"
     done
   done
   ```

   **Traps:** `nix build … | tail` hides the exit code. Use `set -o pipefail`
   or check `$?` directly (repo memory).

5. **Review** (Claude). Run a fresh Opus review on the plan path plus
   `git diff origin/main`. In parallel, run read-only Codex and agy reviews
   through `second-opinion`. Fix what is confirmed. A fix that changes the
   design updates this plan in the same commit.

6. **Switch p620 from the branch and verify** (Claude). Steps:
   - Record checksums for both hosts now, before either switch:

     ```bash
     W=/tmp/claude-1000/-home-olafkfreund--config-nixos/695015ad-b670-442c-bd18-f0346d3c7bdb/scratchpad/layouts
     sha256sum ~/.local/state/omarchy/workspace-layouts/*.lua > "$W/p620-before.sha"
     ssh razer 'sha256sum ~/.local/state/omarchy/workspace-layouts/*.lua' > "$W/razer-before.sha"
     ```

   - Announce on the bus, then run
     `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1 just quick-deploy p620`
   - Run `hyprctl reload`
   - Run the spec's checks 3, 5 and 7:

     ```bash
     for o in general:layout master:orientation master:mfact master:new_status; do hyprctl getoption "$o" | head -1; done
     hyprctl binds -j | jq -r '.[].description' | grep -c -e 'Cycle workspace layout: scrolling' -e '^Layout: '   # expect 4
     sha256sum -c "$W/p620-before.sha"
     hyprctl configerrors
     ```

   - Check 4 needs real key presses, because `cycle` and `by_layout` are local
     closures that `hyprctl dispatch` cannot reach. Either drive them through
     ai-mirror `input` (only if the user grants control), or ask the user to
     press the keys. Read the result after each press from
     `hyprctl activeworkspace -j` (tiledLayout), `hyprctl clients -j` (window
     sizes and positions) and the state file. Report which checks the user
     did.

   **Traps:**
   - First merge `origin/main` into the branch if `main` moved; a stale
     branch rolls back main's changes (repo memory).
   - The bus guard matches words in command text, so put prose in files.

7. **Roll out razer and verify** (Claude). Steps:
   - Announce on the bus, then run
     `AGENT_BUS_ANNOUNCED=1 ALLOW_BRANCH_DEPLOY=1 just deploy-via-p620 razer`
   - Then, over SSH, with
     `HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr | head -1)`:
     `hyprctl reload`, then the same check-3 and check-7 commands as step 6,
     and `sha256sum -c` against `$W/razer-before.sha`

   **Traps:**
   - razer's `switch` may exit 4 from syncthing, which is cosmetic (repo
     memory).
   - p510 is never touched.

8. **PR and merge** (Claude):
   - Open a PR linking the intent, spec and plan, saying which steps Codex
     and the coder did.
   - Comment `@codex review`.
   - Merge when CI is green.
   - Open the nixarchy follow-up issue: a load point after `looknfeel`,
     SUPER+L cycling master and monocle, and bar icons.

## Tests

| What | Command | Expected |
|---|---|---|
| Nix parses | `nix-instantiate --parse hosts/common/nixos/omarchy-layouts.nix` | exit 0 |
| Lua parses | `luac -p` on both built files | exit 0 |
| Hosts build | `just test-host p620`, `just test-host razer` | both succeed |
| Settings loaded | `hyprctl getoption general:layout`, `master:orientation`, `master:mfact`, `master:new_status` | `scrolling`, `right`, `0.65`, `slave` |
| Keys loaded | the `hyprctl binds -j` count in step 6 | 4 |
| Behaviour | spec check 4 | as described |
| Saved choices kept | checksums before and after | identical |
| No errors | `hyprctl configerrors` | empty |

## Rollback

For each host that was switched (p620, and razer once step 7 has run):

1. **Go back to `main`.**
   - **After merge:** revert the PR, then switch the host normally.
   - **Before merge:** run the switch from the main checkout,
     `~/.config/nixos`, which is on `main`. The task worktree is refused by
     `_require-main`. Announce on the bus first, then:

     ```bash
     cd ~/.config/nixos && AGENT_BUS_ANNOUNCED=1 just quick-deploy p620
     cd ~/.config/nixos && AGENT_BUS_ANNOUNCED=1 just deploy-via-p620 razer
     ```

   Home Manager then removes both managed files.
2. **Restore `autostart.lua` straight away**, because Omarchy's `hyprland.lua`
   requires it and the seed only restores it at the next login. Write
   Omarchy's two comment lines; on p620, add the hyprflip line from step 1:

   ```bash
   printf '%s\n' '-- Extra autostart processes.' '-- o.launch_on_start("my-service")' > ~/.config/hypr/autostart.lua
   printf '\n%s\n%s\n' '-- Hyprflip rotating cards (plugin installed by programs.hyprflip).' 'pcall(require, "hypr.hyprflip")' >> ~/.config/hypr/autostart.lua   # p620 only
   ```

3. **`hyprctl reload`** on the host. The old layout, master settings and four
   keys stay in memory until then.

Saved choices are never touched, so there is nothing else to restore.
