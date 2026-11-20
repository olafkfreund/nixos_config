---
status: draft
issue: 3144
intent: intent/2026-11-20-3144-plugins-unload.md
---

# Spec: make pkg, podman, flatsnap and govee safe to unload

## Design

Use the same pattern in all four plugins: nixarchy-devenv's `DevenvState`,
proven for herdr in #3139 (nixarchy-herdr#33). Whatever owns a process that
changes state moves into a `pragma Singleton` file. A `qmldir` lists only
that singleton (`singleton <Name> 1.0 <File>.qml`). The engine owns the
singleton, so a running process outlives the menu's tree. The menus and bar
widgets become views of it.

| Plugin | Becomes the singleton | Notes |
|---|---|---|
| pkg | `PkgModel.qml` → `PkgState` (or `PkgModel` itself as a singleton) | `_writer`, `_reindexer`, `_check` and the apply chain, and `_applyTerm` live there. The menu keeps only view state: tab, message, search |
| podman | `PodmanState.qml` (today one instance in `Menu.qml:99` and one in `Panel.qml:33`) | One shared instance. `active`/`background` polling flags become per-surface requests, because the menu's `active: opened` must not stop the bar's polling |
| flatsnap | `FlatsnapModel.qml` | Menu only, so there are no bar concerns |
| govee | `GoveeClient.qml` (queue and running command) | The bar `Govee.qml` and `GoveeMenu.qml` share it. `dismiss()` stops calling `shell.hide` on Esc and click-away; it hides like the other menus |

Then each `manifest.json` drops `keepLoaded`, and its version gets a minor
bump. Comments saying the menu stays loaded are updated.

A result that arrives while the menu is unloaded stays in the singleton's
state, so the next open shows it. Unlike herdr there is one shared model,
not one per surface, so no owner routing is needed.

**This repo:**

- `flake.nix`: override `nixarchy-pkg`, `nixarchy-podman` and
  `nixarchy-flatsnap` to their merge commits, with "remove once nixarchy
  edge pins X or later" comments, following #3107 and #3139.
- A new `omagovee` input (`flake = false`), pinned to its merge commit.
- A module, `hosts/common/nixos/omarchy-govee.nix`, set as
  `programs.nixarchy.plugins."olafkfreund.govee".src = "${omagovee}/plugin"`
  and imported by p620 and razer, the hosts that have the hand copy today.
  The hand-copied `~/.config/omarchy/plugins/olafkfreund.govee` must be
  moved aside once before the first switch, because nixarchy symlinks
  there.

## Alternatives rejected

- **herdr's per-model slots:** those were needed there only because the
  bar has one model per monitor with its own concurrency. These plugins
  already share one rule ("one mutation at a time") or are menu-only.
- **Keep `keepLoaded`:** the owner chose to drop it.

## Risks

- **Podman's polling:** with one shared state, the bar and the menu must
  both be able to ask for polling. Today the menu polls only while open.
- **A changed singleton lifetime:** a singleton lives for the whole shell
  session, so its memory stays allocated after the menu closes. This is the
  same as `keepLoaded` today.
- **Each repo's own tests** may extract functions or check process ids by
  source text, like herdr's `session-actions.cjs`. They must be updated,
  not weakened.

## Verification

- Each plugin repo: its own CI, plus local QML loading where it has a
  test, and a check that the manifest has no `keepLoaded`.
- This repo: `just test-host p620` and `just test-host razer`.
- p620 after a switch and a login:
  - none of the four menus is built before its first open, per the probe's
    layer events and the shell log;
  - each still opens, acts and closes;
  - govee: Esc hides it and the keybind toggles it.
- razer: the deploy succeeds, with the plugins installed and no
  `keepLoaded`.
