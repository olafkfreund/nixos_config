---
status: approved
issue: 2503
author: olafkfreund
---

# Intent: Altscape Alt+Tab switcher on p620 and razer, set up so it sticks

## Problem

Altscape (qempexe/omarchy-altscape, MIT, 1.0.2) is an Omarchy shell plugin:
an Alt+Tab window switcher with live previews, eight layouts and a settings
panel. Neither host has it, and installing it the documented way
(`omarchy plugin add`) wouldn't work here or wouldn't last:

- **Its keybinding never loads.** `bin/altscape-binds` writes its Alt+Tab
  block into `~/.config/hypr/hyprland.lua` whenever that file exists, which it
  does on p620. Hyprland here runs `--config <store>/hyprland.lua`, so that
  file is ignored. The plugin would load, Alt+Tab would never reach it, and
  its own check would report `active: false`.
- **The rest is manual state on one machine.** `omarchy plugin add` clones
  into `~/.config/omarchy/plugins`, unpinned and outside this repo. Enabling
  goes into `shell.json`. The fallback home for the binding,
  `~/.config/hypr/bindings.lua`, is a hand-edited file that this repo doesn't
  track. None of that is reproducible, and razer would differ from p620.
- **p620 has a stale Tab binding.** Its `bindings.lua` still sends Super+Tab
  and Alt+Tab to `io.github.woogy7.workspaces`, which no longer appears in
  `omarchy plugin list`, so those keys may already be dead.

## Proposed outcome

- On p620 and razer, after a deploy and with no hand edits, Alt+Tab and
  Alt+Shift+Tab open Altscape and cycle windows, and releasing Alt switches.
  Super+Alt+Shift+S opens its settings.
- The plugin version is pinned in this repo and upgraded by a bump, never by
  `omarchy plugin update`.
- The keybinding comes from Nix, so it survives deploys, reboots, garbage
  collection and plugin bumps. The plugin never edits Hyprland config files.
- p620's dead woogy7 Tab bindings are gone, and nothing else fights for Tab.
- Altscape's settings (layout, look) stay yours to change at runtime and
  persist in `~/.local/state/omarchy-altscape`.

## Affected users and systems

- Hosts: p620 and razer. p510 is not touched.
- Files: a new `pkgs/altscape`, a new `hosts/common/nixos/omarchy-altscape.nix`
  (as with omapop, #2498), each host's `nixos/nixarchy.nix`, and whatever
  carries the Hyprland binding declaratively.
- p620's `~/.config/hypr/bindings.lua`: the woogy7 block is removed.

## Constraints

- Follow the omapop pattern: a pinned package with `substituteInPlace
  --replace-fail`, wired through `programs.nixarchy.plugins.<id>.src`. Don't
  fork or patch nixarchy.
- Never write into `~/.config/hypr/hyprland.lua`; it is dead here.
- Don't take ownership of all of `bindings.lua` (it holds your own binds).
  Anything added there must coexist with your edits.
- Restart the shell cleanly after enabling (memory: hot-reload can leave two
  shells running).
- Deploy p620 locally and razer via p620, announced on the bus.

## Open questions

1. **Enabling:** nixarchy's `plugins` option installs but doesn't enable.
   Accept a one-time `omarchy plugin enable io.github.qempexe.altscape` per
   host, or have the config enable it once at first login (the way
   `defaultPlugins` does with its enabled-once marker)?
2. **Super+Tab on p620:** today it is bound to the woogy7 picker. When that
   block goes, should Super+Tab fall back to Omarchy's default (next
   workspace), or also open Altscape (it has a `super` mode)?
3. **Bar widget:** add Altscape's bar widget to the bar, or keyboard only?
