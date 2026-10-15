---
status: approved
issue: 2306
intent: intent/2026-10-15-2306-group-aware-bar-widget.md
---

# Spec: the Omarchy bar shows and switches workspace groups

## Design

Two small changes. Both go in `hosts/common/nixos/omarchy-workspaces.nix`, which
p620, razer and p510 already import, plus one patch file next to it.

### 1. Export the group switch from the Lua config

At the end of the generated `workspace-groups.lua`, add one global:

```lua
-- The bar's workspace widget calls this through `hyprctl eval` (#2306).
WorkspaceGroups = { focus = focus_group }
```

`hyprctl eval` runs in the config's own Lua state. Checked live on p620:
`hyprctl eval 'error(type(o))'` reports `table`, so Omarchy's `o` helper, which
the config defines, is visible there, and so will a global set by
`workspace-groups.lua`. A global assignment does nothing harmful under the
keybindings menu's stub `hl`.

`hyprctl dispatch` cannot do this. It wraps its argument as
`hl.dispatch(<expr>)` (as the probe's error message shows), and `focus_group`
returns nil, not a dispatcher.

### 2. Patch the stock widget

New file `hosts/common/nixos/omarchy-workspaces-bar.patch` against
`share/omarchy/shell/plugins/bar/widgets/Workspaces.qml` (omarchy 4.0.4).
`WS_PER_MONITOR` is 10, so the widget folds each workspace id to its group
with `(id - 1) % 10 + 1`:

| Stock line | Becomes |
| ---------- | ------- |
| 26: keep ids 1-10 | keep `groupOf(id)` for every `id > 0` (negative ids are special workspaces) |
| 58: `occupied` = workspace `modelData` has toplevels | any workspace with `id > 0 && groupOf(id) === modelData` has toplevels |
| 59: `focused` = focused id `=== modelData` | focused id `> 0 && groupOf(focused id) === modelData` |
| 35: `hyprctl dispatch hl.dsp.focus({ workspace = id })` | `hyprctl eval WorkspaceGroups.focus(id)` |

`workspaceById` is then unused and goes. The labels, the icons and the
`[1..5]` floor stay as they are. With one screen every id is already 1-10 and
`groupOf(id) === id`, so razer and p510 behave exactly as stock.

The patch is applied the way nixarchy applies its own Omarchy patches
(`pkgs/omarchy/default.nix:439`), in `postInstall`:

```nix
omarchy = (pkgs.extend inputs.nixarchy.overlays.default).omarchy.overrideAttrs (old: {
  postInstall = (old.postInstall or "") + ''
    patch -d "$out/share/omarchy" -p1 --forward --fuzz=0 < ${./omarchy-workspaces-bar.patch}
  '';
});
```

`--fuzz=0` makes an upstream change to the widget fail the build instead of
silently reverting to the stock behaviour. That meets the intent's
"fail visibly" constraint.

The patched package is set as both `programs.nixarchy.package` (NixOS) and
`home-manager.users.olafkfreund.programs.nixarchy.package`. The NixOS option
feeds `programs.nixarchy.tree`, which is `OMARCHY_PATH` for the session and for
Home Manager. The HM option is set too, so the user profile does not carry a
second, unpatched omarchy build; nixarchy's own comment warns that `buildEnv`
rejects two builds of the same package. The expression reproduces the module's
default (`modules/nixos.nix:397`), built from our nixpkgs through nixarchy's
overlay. It reads `inputs.nixarchy` and never `config.programs.nixarchy.package`:
that read closes the module fixpoint (see `modules/desktop/stylix-theme.nix:22`).

## Alternatives rejected

- **A user Omarchy bar plugin with a cloned widget.** Rejected at intent
  approval: it is a second copy to keep in step with upstream, and it breaks
  silently when upstream changes.
- **Switching each monitor from QML** (one `focus` per screen). This repeats the
  position-based block ordering in a second language. The two copies would
  drift, and the "bring the other screens along" behaviour would no longer be
  in one place.
- **Overriding through `patches`.** nixarchy applies its own patches to
  `$out` in `installPhase`, not to `src`. Patching `$out` in `postInstall`
  anchors against the same final tree as theirs, after all of their edits.
- **An upstream hook** (a configurable id→group map in Omarchy). Out of scope
  at intent approval.

## Risks

- **`OMARCHY_PATH` is frozen at login.** The new widget appears only in a
  fresh session. `omarchy-restart-shell` in a session whose tree differs from
  the current system kills every keybind (see memory
  project_omarchy_path_stale_session). So the runtime check on p620 needs a
  log out and back in, not a shell restart.
- **Rebuild size.** Changing the omarchy store path rebuilds everything that
  embeds it: the session wrapper, units, rc files and SDDM theme. These should
  all be text derivations. A `--dry-run` count will confirm that before
  deploying.
- **A future omarchy bump** that touches `Workspaces.qml` fails the build on all
  three hosts until the patch is re-anchored. This is intended, but it shows up
  in `nhs`/CI as a build failure.
- **Hosts without the groups module** would get an `attempt to index nil` error
  on click. There are none: all three import it, and the patch is set in the
  same file.
- p510 builds only when you ask.

## Verification

1. Eval and build: `just check-syntax`, `just test-host p620`,
   `just test-host razer`. Show the omarchy derivation count with
   `nix build --dry-run`.
2. The built tree contains the patched widget: `grep -n groupOf` on
   `share/omarchy/shell/plugins/bar/widgets/Workspaces.qml` in the new
   omarchy output.
3. After deploying to p620, before logging in again:
   `hyprctl eval 'WorkspaceGroups.focus(3)'` switches all three screens to 3,
   11+2 and 21+2 (`hyprctl -j monitors`).
4. After logging in again on p620:
   - focus DP-3 or the HDMI: the dot stays on the current group on every bar;
   - a group whose only window is on screen 3 shows as occupied;
   - clicking a number moves all three screens (`hyprctl -j monitors`).
5. razer: the bar looks and behaves as stock on the laptop panel.
