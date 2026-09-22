---
status: approved
issue: 1971
intent: intent/2026-09-22-1971-plugin-browser-panel.md
---

# Spec: Plugin Browser as Add Plugin, and on Super+Alt+U, on p620

## Design

One new file, shaped exactly like its neighbour `hosts/common/nixos/omarchy-gog.nix`,
and one import line.

### `hosts/common/nixos/omarchy-plugin-browser.nix` (new)

```nix
# The Plugin Browser (olafkfreund/nixarchy-plugin-browser) as this desktop's
# way to add a plugin: a menu row and a keybinding. The plugin itself is
# installed with its own install.sh and enabled with `omarchy plugin enable`;
# this file only points the desktop at it.
#
# Setup > Plugins > Add Plugin is overridden by id. An override that omits a
# key blanks it instead of inheriting it (MenuModel.js normalizes the row
# first), so icon, label and action are all restated.
#
# The keybinding rides in its own lua file for the reason omarchy-gog.nix
# gives: bindings.lua stays user-owned and keeps one hand-written
#   pcall(require, "hypr.plugin-browser-binds")
# and pcall, not require, so a rollback that drops this file cannot take the
# whole Hyprland config down.
{ ... }:
{
  programs.nixarchy.menu.extraEntries."setup.plugin.add" = {
    icon = "󰖟";
    label = "Add Plugin";
    action = "omarchy-shell shell toggle io.github.olafkfreund.nixarchy-plugin-browser '{}'";
  };

  home-manager.users.olafkfreund.home.file.".config/hypr/plugin-browser-binds.lua".text = ''
    -- Managed by hosts/common/nixos/omarchy-plugin-browser.nix -- edits here
    -- are overwritten on the next deploy.
    o.bind("SUPER + ALT + U", "Plugin browser", "omarchy-shell shell toggle io.github.olafkfreund.nixarchy-plugin-browser '{}'")
  '';
}
```

- The icon `󰖟` is the default row's own, so the row looks unchanged.
- The action is a plain string. The menu runs it with `Quickshell.execDetached`,
  as it runs every row.
- `o.bind` takes the same three arguments as `gog-binds.lua` and the
  plugin's shipped `hypr/plugin-browser-binds.lua`.

### `hosts/p620/nixos/nixarchy.nix`

One line, appended to `imports` after `../../common/nixos/omarchy-stylix-theme.nix`:

```nix
    ../../common/nixos/omarchy-plugin-browser.nix
```

In-flight #1967 adds two lines at the same place: `inputs.hyprflip...` and
`omarchy-hyprflip.nix`. Whichever branch merges second keeps all three lines.

### Outside the repo (by hand, with consent)

`~/.config/hypr/bindings.lua` gets one line next to the other `pcall`s:

```lua
pcall(require, "hypr.plugin-browser-binds")
```

## Alternatives rejected

- **A `features.pluginBrowser.enable` module under `modules/`,** the shape
  AGENTS.md shows. Every `omarchy-*.nix` beside this file is a plain module
  that the host enables by importing it. That shape is consistent with its
  neighbours, and an option with one caller is ceremony.
- **Hand-editing `~/.config/omarchy/extensions/omarchy-menu.jsonc`.** Since
  nixarchy #220 it is writable and a hand edit would survive, but it is
  invisible to review and differs per machine. Decided at the intent.
- **Reading the binds file from the plugin repo** (a flake input, or a path
  into its checkout). It would add a flake input to save one line, and it
  would tie a rebuild to the plugin checkout existing.
- **razer as well.** Decided at the intent: p620 only.

## Risks

- **The plugin is not installed or enabled.** The row and the key then call
  `omarchy-shell shell toggle` on an unknown plugin, and nothing opens.
  - Recoverable: install and enable it (`./install.sh --plugin`, `omarchy
    plugin enable io.github.olafkfreund.nixarchy-plugin-browser`).
  - Removing the import restores the old row.
  - The deploy order in Verification avoids a gap.
- **A merge conflict with #1967** in the imports list: a one-line
  resolution, already flagged on the bus by both sides.
- **Super+Alt+U collisions.** It is free in `~/.config/hypr` and nixarchy's
  defaults today; only Super+Ctrl+Alt+U (hyprflip.lua) and Super+Alt+Up exist.
  A future default taking it would show up as two binds under Super+K.

## Verification

- **Evaluation, no build and no deploy:**
  - `nix eval .#nixosConfigurations.p620.config.programs.nixarchy.menu.extraEntries --json | jq '."setup.plugin.add"'`
    returns the three keys above.
  - `nix eval --raw '.#nixosConfigurations.p620.config.home-manager.users.olafkfreund.home.file.".config/hypr/plugin-browser-binds.lua".text'`
    contains the `o.bind` line.
  - `nix eval .#nixosConfigurations.razer.config.programs.nixarchy.menu.extraEntries --json | jq 'has("setup.plugin.add")'`
    is `false` (p620 only).
  - The repo's own pre-commit hooks pass.
- **After the user deploys p620,** announced on the bus first:
  - `~/.config/hypr/plugin-browser-binds.lua` exists.
  - With the `pcall` line, Super+Alt+U toggles the panel.
  - Setup → Plugins → Add Plugin opens it.
  - The other four Plugins rows still work.
