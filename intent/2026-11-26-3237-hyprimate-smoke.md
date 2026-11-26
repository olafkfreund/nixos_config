---
status: draft
issue: 3237
author: olafkfreund
---

# Intent: hyprimate window animations, smoke by default, on p620 and razer

## Problem

Opening, closing and moving a window on the Omarchy session uses Hyprland's stock animations. The owner wants the
[hyprimate](https://github.com/JustinBacher/hyprimate) plugin's Smoke style instead, on both desktops, and today it
exists only as a hand-loaded test on p620 that is gone at the next login.

What the 2026-11-26 live test on p620 established:

- hyprimate 0.1.0 (upstream `9e667f9`) builds with its own flake when its `hyprland` input is set to nixarchy's pin
  (`64bde62`); the Hyprland store path then equals the running compositor's, and the plugin's post-link symbol check
  passes. Upstream's flake needs no patch.
- `hyprctl plugin load <store path>` loads it, and `hl.config({ plugin = { hyprimate = { window = { style = "smoke" } } } })`
  switches style live.
- Omarchy ignores `~/.config/hypr/hyprland.lua`; a drop-in must be required from a file the session loads (as
  Omarchy's own titlebars plugin is loaded with `hl.plugin.load` in `workspace-modes.lua`).

## Proposed outcome

After a deploy and a fresh login on p620 and razer, hyprimate is loaded and windows open, close and move with the
Smoke style, with no manual command. A Hyprland bump through `nix flake update nixarchy` rebuilds the plugin against
the new compositor automatically. One flag per host turns it off.

## Affected users and systems

- Hosts: p620 and razer (both run the same nixarchy Hyprland). Not p510.
- `flake.nix` / `flake.lock` (new input), a new module, the two hosts' configs, the Lua drop-in under
  `~/.config/hypr/`, and docs.

## Constraints

- The plugin must be built against the exact Hyprland the session runs; it follows nixarchy's pin, never its own.
- Declarative only: no `hyprpm`, no hand-made files in `~/.config/hypr`.
- A plugin runs inside the compositor: a crash ends the session. Disabling must be one flag and a re-login.
- A new plugin store path takes effect only at the next login, not at switch.
- Hyprland's `decoration.wobble` conflicts with hyprimate and must be off where it loads.
- Upstream is young (0.1.0, one author, daily commits): pin a rev, bump deliberately.
- p510 is out of scope and is not built or deployed.

## Open questions

1. Smoke settings: upstream defaults, or tune anything (direction, density, colour) now?
2. Workspace-switch animation (off upstream by default): keep it off?
