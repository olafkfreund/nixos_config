---
status: approved
issue: 2074
intent: intent/2026-09-29-2074-nixarchy-menu-snowflake.md
---

# Spec: nixarchy-menu back on p620 and razer, wearing the NixOS snowflake

## Design

Two changes, in dependency order.

### 1. nixarchy patches nixarchy-menu's bar button (upstream, `olafkfreund/nixarchy`)

nixarchy already does this for the stock menu. `pkgs/omarchy/default.nix`
replaces `shell/plugins/menu/BarWidget.qml` with
`pkgs/omarchy/menu-bar-widget.qml`, which hides the glyph's label
(`labelVisible: false`) and draws
`${nixos-icons}/share/icons/hicolor/256x256/apps/nix-snowflake.png` over
it. The same change goes on nixarchy-menu's button, at the place nixarchy
pulls the plugin in:

- `modules/home.nix`, the `menu` default-plugin entry (currently
  `src = inputs.nixarchy-menu.packages.<system>.plugin`), gets a patched
  source instead: `pkgs.applyPatches`, or a `runCommand` that copies the
  plugin, with
  - a new `pkgs/nixarchy-menu/snowflake-button.patch` applied with
    `--fuzz=0` to `BarWidget.qml` (pinned at nixarchy-menu `2cce175`,
    v1.0.0). The patch touches only the first `WidgetButton` (`id:
    button`). It adds `labelVisible: false` and an `Image` child that is
    identical to the one in `menu-bar-widget.qml`: centred, side
    `Math.round(button.fontSize * 1.3)`, `mipmap`, and dimmed with the
    button.
  - `substituteInPlace --subst-var-by snowflake <png path>`, the same
    placeholder the stock widget uses.
- Everything else in nixarchy-menu's `BarWidget.qml` stays as it is: the
  `omarchy.menu` toggle, right-click opening a terminal, the `barList`
  `Repeater` for provider items, and the `moduleName`.

This answers the intent's first open question: nixarchy-menu stays
distro-neutral, and nixarchy adds the snowflake, as it does for the stock
menu. It also answers the second: the snowflake is always on for anyone
using nixarchy-menu through nixarchy, with no option, matching the stock
button. That is also what nixarchy#1052 needs. Its draft intent (2026-09-29,
branch `feat/1052-menu-on-by-default`) makes nixarchy-menu the default on
every machine. Without this patch, that change would swap the snowflake for
the Omarchy mark everywhere. The two changes do not overlap in code: #1052
flips `enableByDefault`, and this changes `src`. Whichever lands second
rebases.

The nixarchy change is filed as its own issue, with its own intent, spec
and plan in that repo as its rules require. Its spec can reuse this design
word for word.

### 2. This repo restores the opt-in and bumps the lock

- `hosts/p620/nixos/nixarchy.nix` and `hosts/razer/nixos/nixarchy.nix`:
  put back the three lines #2070 removed, with the comment updated:

  ```nix
  # nixarchy-menu as the Omarchy menu (#2019, #2074); nixarchy draws the
  # snowflake on its bar button.
  home-manager.users.olafkfreund.programs.nixarchy.defaultPlugins.menu = true;
  ```

  If nixarchy#1052 has landed by then, the line is redundant and is
  dropped instead. The lock bump alone then brings the menu back.
- `flake.lock`: `nix flake update nixarchy` to the merge that carries
  change 1.
- p510 is unchanged. It keeps the stock menu and never sets the opt-in.

## Alternatives rejected

- **nixarchy-menu draws the snowflake itself.** One file, but it ties a
  plugin that also runs on Arch Omarchy to NixOS. The intent asked for it
  to stay distro-neutral, which rules this out.
- **An `icon` setting in nixarchy-menu that nixarchy fills in.** It would
  be distro-neutral, but it needs changes in two repos plus a config key
  that only one consumer ever sets. Add it if a second distro wants its own
  mark.
- **Replace nixarchy-menu's whole `BarWidget.qml`, as is done for the
  stock menu.** That file carries the `barList` repeater and the panel
  lookup. A full replacement would fork them silently, and nixarchy-menu
  updates would stop reaching the button. A `--fuzz=0` patch changes a few
  lines and fails the build when upstream rewrites them.
- **A host-local override in this repo** (patching the plugin under
  `programs.nixarchy.plugins."nixarchy.menu".src` for p620 and razer only).
  It is the smallest diff here, but every other nixarchy user, and all of
  them after #1052, would still see the wrong mark. The fix belongs where
  the stock button's fix lives.
- **Revert #2070 and accept the Omarchy mark.** The user declined this.

## Risks

- **The patch goes stale when nixarchy-menu is bumped.** Because of
  `--fuzz=0`, the nixarchy build fails and nothing ships without the
  snowflake. The cost is that each nixarchy-menu bump may need the patch
  refreshed.
- **An SVG shows nothing.** Only the PNG is used. quickshell has no SVG
  image plugin.
- **The bar slot hand-back** (nixarchy#946). Turning `nixarchy.menu` back
  on disables `omarchy.menu` in the same slot through the enable-once hook.
  After #2070, the enabled-once marker for `nixarchy.menu` may still be
  recorded as off on p620 and razer ("Disabled nixarchy.menu" in the
  journal at 07:34 and 07:35). If the hook then refuses to re-enable it,
  the menu stays off after the switch. The build check below cannot see
  this, so the runtime check covers it, and the fix is
  `omarchy plugin enable nixarchy.menu` once per host.
- **Shell reload.** The plugin reload is stale for widgets already on
  screen (see memory: Omarchy plugin reload is stale). The button may keep
  the old glyph until the shell restarts or the user logs in again.
- **Hosts.** p620 is built and deployed locally. razer is built on p620 via
  `just deploy-via-p620 razer`. p510 is neither built nor deployed.

## Verification

- nixarchy: `nix flake check` passes, including `tests/options.nix`
  (`menuValidated`: the patched plugin still validates as `nixarchy.menu`)
  and `tests/qml.nix` with the patched `BarWidget.qml` added to its lint
  list. A new assertion greps the patched `BarWidget.qml` for
  `nix-snowflake.png` and `labelVisible: false`.
- This repo: `just test-host p620` and `just test-host razer` build. The
  p620 Home Manager activation references `nixarchy.menu` again, which
  #2070 recorded as 3 references before the removal and 0 after.
- Runtime, on p620 and razer after the deploy:
  - `omarchy plugin list` shows `nixarchy.menu enabled` and `omarchy.menu`
    disabled.
  - The plugin's installed `BarWidget.qml` contains `nix-snowflake.png`.
  - A screenshot of the bar's menu slot shows the snowflake.
  - `Super+Space` opens the palette.
  - Starting a timer shows its countdown next to the button.
- p510: `omarchy plugin list` is unchanged (a read-only check; nothing is
  deployed there).
