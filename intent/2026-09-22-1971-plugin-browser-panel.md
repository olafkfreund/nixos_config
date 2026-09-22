---
status: draft
issue: 1971
author: olafkfreund
---

# Intent: Plugin Browser as Add Plugin, and on Super+Alt+U, on p620

## Problem

The nixarchy-plugin-browser plugin now ships a full-screen, keyboard-driven
panel inside the Omarchy shell (olafkfreund/nixarchy-plugin-browser#4, PR #5).
Before installing a marketplace plugin, the panel searches the marketplace,
audits the plugin in a sandbox, and checks whether it will run on NixOS. On
p620 nothing leads to it:

- **Setup → Plugins → Add Plugin** still runs a bare `omarchy-plugin-add` in a
  terminal. It clones whatever is at the repo's HEAD, with no audit and no
  NixOS check. That is the path people actually use to add a plugin.
- **There is no keybinding.** The panel ships `hypr/plugin-browser-binds.lua`
  (Super+Alt+U), but on this machine binds files are provided declaratively,
  as `omarchy-gog.nix` does for `gog-binds.lua`, so a hand-copied file would
  drift.

## Proposed outcome

On p620, after a deploy:

- **Setup → Plugins → Add Plugin** opens the Plugin Browser panel. It keeps
  the label "Add Plugin" and its icon, so it stays recognisable.
- **Super+Alt+U** opens and closes the panel, and it is listed in Omarchy's
  key bindings menu (Super+K).
- Enable, Disable, Clone and Remove are unchanged.
- Removing one import brings the old Add Plugin row back.

## Affected users and systems

- **p620 only**, olafkfreund's session. razer is not included: it can import
  the same module later.
- New file: `hosts/common/nixos/omarchy-plugin-browser.nix`. It is shaped like
  `omarchy-gog.nix`: an `extraEntries` row plus a Home Manager binds file.
- `hosts/p620/nixos/nixarchy.nix`: one import line.
- `~/.config/hypr/bindings.lua` gets one
  `pcall(require, "hypr.plugin-browser-binds")` line. That file is
  user-owned, so the line is added by hand, with consent, outside this repo.
- The plugin must be installed and enabled for the row and the key to open
  anything: `./install.sh --plugin`, then `omarchy plugin enable io.github.olafkfreund.nixarchy-plugin-browser`.

## Constraints

- **Do not disturb the in-flight hyprflip work.** It is staged on `main` and
  touches the same imports list. This change lives on its own branch in a
  separate worktree, and the one-line conflict is resolved by whichever of
  them lands second.
- **The override row carries `icon`, `label` and `action`.** An override that
  omits a key blanks it rather than inheriting it (nixarchy #220 notes).
- **Bus rule:** announce any deploy before running it. Only the user deploys.
- **No change to the plugin's own security behaviour.** This only adds entry
  points to it.

## Open questions

- **Include razer now, or p620 only?** The proposal is p620 only.
- **`extraEntries` or the extensions file?** Since nixarchy #220,
  `~/.config/omarchy/extensions/omarchy-menu.jsonc` is a writable user file,
  so a hand edit would now survive. The proposal is `extraEntries`, because
  it is declarative and reviewable here, like the existing gog rows.
