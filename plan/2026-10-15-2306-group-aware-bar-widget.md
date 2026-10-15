---
status: approved
issue: 2306
spec: spec/2026-10-15-2306-group-aware-bar-widget.md
---

# Plan: the Omarchy bar shows and switches workspace groups

## Approved decisions (from the spec)

- Patch Omarchy's stock `share/omarchy/shell/plugins/bar/widgets/Workspaces.qml`
  (omarchy 4.0.4). Do not clone it into a user plugin, and do not offer an
  upstream hook.
- The widget folds every workspace id `> 0` to its group, `(id - 1) % 10 + 1`,
  for the list of numbers, `occupied` and `focused`. Negative ids are special
  workspaces and are ignored.
- On click it runs `hyprctl eval 'WorkspaceGroups.focus(<n>)'`. Not
  `hyprctl dispatch`: that wraps its argument in `hl.dispatch(...)`.
- `workspace-groups.lua` exports `WorkspaceGroups = { focus = focus_group }`.
  `hyprctl eval` shares the config's Lua state; checked live on p620.
- Apply the patch in `postInstall` with
  `patch -d "$out/share/omarchy" -p1 --forward --fuzz=0`, the same way nixarchy
  applies its own patches (`pkgs/omarchy/default.nix:439`). An upstream change
  then fails the build instead of silently reverting.
- Set the patched package as both NixOS `programs.nixarchy.package` and
  `home-manager.users.olafkfreund.programs.nixarchy.package`. Build it from
  `(pkgs.extend inputs.nixarchy.overlays.default).omarchy`, the module's own
  default expression.
- Everything goes in `hosts/common/nixos/omarchy-workspaces.nix` (imported by
  p620, razer and p510), plus the new patch file next to it.

Two files, two editing steps, so the session model implements this itself
(below the coder hand-off threshold).

## Steps

1. **New `hosts/common/nixos/omarchy-workspaces-bar.patch`.** Write the
   unified diff below, with plain `a/` and `b/` headers and no timestamps. It was
   dry-run against the 4.0.4 file with `--fuzz=0` and applies cleanly.

   ```diff
   --- a/shell/plugins/bar/widgets/Workspaces.qml
   +++ b/shell/plugins/bar/widgets/Workspaces.qml
   @@ -8,13 +8,19 @@
      id: root
      moduleName: "omarchy.workspaces"

   -  function workspaceById(id) {
   +  // Workspace groups (hosts/common/nixos/omarchy-workspaces.nix): group N is
   +  // workspace N, N+10 and N+20, one per display.
   +  function groupOf(id) {
   +    return (id - 1) % 10 + 1
   +  }
   +
   +  function groupOccupied(group) {
        var values = Hyprland.workspaces.values
        for (var i = 0; i < values.length; i++) {
   -      if (values[i].id === id) return values[i]
   +      if (values[i].id > 0 && groupOf(values[i].id) === group && values[i].toplevels.values.length > 0) return true
        }

   -    return null
   +    return false
      }

      function workspaceIds() {
   @@ -23,7 +29,7 @@

        for (var i = 0; i < values.length; i++) {
          var id = values[i].id
   -      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
   +      if (id > 0 && ids.indexOf(groupOf(id)) === -1) ids.push(groupOf(id))
        }

        ids.sort(function(left, right) { return left - right })
   @@ -32,7 +38,7 @@

      function focusWorkspace(id) {
        if (!root.bar) return
   -    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
   +    root.bar.run("hyprctl eval " + Util.shellQuote("WorkspaceGroups.focus(" + id + ")"))
      }

      readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)
   @@ -54,9 +60,8 @@
          WidgetButton {
            required property int modelData

   -        readonly property var workspace: root.workspaceById(modelData)
   -        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
   -        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
   +        readonly property bool occupied: root.groupOccupied(modelData)
   +        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id > 0 && root.groupOf(Hyprland.focusedWorkspace.id) === modelData

            bar: root.bar
            text: focused ? "󱓻" : (modelData === 10 ? "0" : String(modelData))
   ```

   Verify: copy the store file into a scratch tree, then run
   `patch -p1 --forward --fuzz=0 --dry-run` against it.

   Traps:
   - Context lines start with one space. The pre-commit "trim trailing
     whitespace" hook must not strip the blank context lines; they are a single
     space. Check with `git diff --check` after staging, and re-run the dry run
     on the committed file.
   - Keep the patch out of any formatter's path.

2. **`hosts/common/nixos/omarchy-workspaces.nix`.**
   - Line 30, `{ ... }:`, becomes `{ inputs, pkgs, ... }:`. `inputs` is in
     `specialArgs`; `omarchy-pixelbuds.nix:7` uses the same signature.
   - Before line 32, add a `let` that binds `omarchy` to
     `(pkgs.extend inputs.nixarchy.overlays.default).omarchy.overrideAttrs`,
     appending to `postInstall` (keeping `old.postInstall or ""`):
     `patch -d "$out/share/omarchy" -p1 --forward --fuzz=0 < ${./omarchy-workspaces-bar.patch}`.
   - Set `programs.nixarchy.package = omarchy;` and
     `home-manager.users.olafkfreund.programs.nixarchy.package = omarchy;`.
   - Before the closing `''` at line 298, append to the Lua text:

     ```lua
     -- The bar's workspace widget calls this through `hyprctl eval` (#2306).
     WorkspaceGroups = { focus = focus_group }
     ```

   - In the header comment, add one line saying that the file also patches the
     bar widget, and why.

   Verify: `just check-syntax`.

   Traps:
   - Never read `config.programs.nixarchy.package`: that is infinite recursion
     (`modules/desktop/stylix-theme.nix:22`).
   - The Lua must stay safe under the keybindings menu's stub `hl`. A global
     assignment is.
   - Rule 4 (no `mkIf cond true`) does not apply here.
   - Keep comments minimal (user feedback).

3. **Build both desktop hosts.**
   - Run `just test-host p620` and `just test-host razer`.
   - Before deploying, list what will rebuild with
     `nix build --dry-run .#nixosConfigurations.p620.config.system.build.toplevel`.
     Expect the omarchy derivation plus text derivations only. Stop and report if
     anything compiled shows up (quickshell, hyprland).
   - In the new omarchy output, `grep -n groupOf` on
     `share/omarchy/shell/plugins/bar/widgets/Workspaces.qml` finds 4 matches.

   Traps:
   - Use `set -o pipefail` when piping `nix build`.
   - Do not build p510 without asking.

4. **Commit and PR.**
   - Commit `feat(omarchy): group-aware bar workspace widget (#2306)`. Write the
     message to a file and pass it with `-F`, with no backticks inside `-m`.
   - Push, and open a PR linking the intent, spec and plan.
   - Deploy only on request: p620 locally, razer via `just deploy-via-p620 razer`.
     Announce on the agent bus first.

## Tests

| Check | Expected |
| ----- | -------- |
| `just check-syntax` | passes |
| `just test-host p620`, `just test-host razer` | build; the patch applies at `--fuzz=0` |
| `grep -c groupOf …/Workspaces.qml` in the built omarchy | 4 |
| After the p620 deploy, in the current session: `hyprctl eval 'WorkspaceGroups.focus(3)'`, then `hyprctl -j monitors` | screens on 3, 13, 23 |
| After logging out and in on p620: focus DP-3 or HDMI | the dot stays on the current group on every bar |
| A group whose only window is on screen 3 | its number shows as occupied |
| Click a number | all three screens switch |
| razer | the bar looks and behaves as stock |

Do not run `omarchy-restart-shell` to see the widget. `OMARCHY_PATH` is frozen
at login, and a restart in a stale session kills every keybind. Log out and
back in instead.

## Rollback

Revert the commit, which drops the package override, the patch file and the Lua
global, then rebuild. Log out and back in to get the stock widget. On the host
itself, the previous generation from the boot menu, or
`nixos-rebuild switch --rollback`, also restores it.
