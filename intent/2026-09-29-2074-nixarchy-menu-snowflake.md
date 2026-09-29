---
status: draft
issue: 2074
author: olafkfreund
---

# Intent: nixarchy-menu back on p620 and razer, wearing the NixOS snowflake

## Problem

p620 and razer have to choose between two things they should get together:

- **nixarchy-menu**, the Raycast-style palette (search providers, timer,
  voice, extensions). It was the menu on both hosts from #2019.
- **The NixOS snowflake** in the bar's menu slot. nixarchy swaps the stock
  `omarchy.menu` bar button for its own `pkgs/omarchy/menu-bar-widget.qml`,
  which draws `nix-snowflake.png`. p510 shows the snowflake this way.

nixarchy-menu brings its own `BarWidget.qml`. It draws the Omarchy glyph
(`""`, font `omarchy`), and nothing in nixarchy patches it. With the menu
on, the slot showed the Omarchy mark instead of the snowflake. #2070 fixed
the icon by removing the menu, and nixarchy-default-plugins disabled
`nixarchy.menu` on p620 at 07:34 on 2026-09-29 and on razer at 07:35.

## Proposed outcome

On p620 and razer after a deploy:

- nixarchy-menu is the menu again, opened by the same button and keybind
  as before #2070.
- The bar's menu button shows the NixOS snowflake at the same size and
  position as the stock button on p510.
- The palette's bar items, such as the Timer countdown, still appear next
  to the button.
- `~/.config/omarchy/nixarchy-menu.json` on p620 is picked up again as it
  is (browser-search and timer providers on).

## Affected users and systems

- Hosts: p620 and razer. p510 stays on the stock menu and must not change.
- This repo: `hosts/p620/nixos/nixarchy.nix` and
  `hosts/razer/nixos/nixarchy.nix` (restore the `defaultPlugins.menu`
  opt-in), plus a `flake.lock` bump.
- Upstream: the snowflake has to come from `olafkfreund/nixarchy`, which
  already patches the stock button, or from `olafkfreund/nixarchy-menu`,
  which owns the button. The spec decides which.
- Anyone else using nixarchy with `defaultPlugins.menu = true` gets the
  same snowflake.

## Constraints

- Keep what the nixarchy-menu button already does: left click toggles
  `omarchy.menu`, right click opens a terminal, and bar items render and
  are clickable.
- Use the PNG, not the SVG. nixpkgs' quickshell has no Qt SVG image plugin,
  so an SVG `Image` renders nothing (the note in `menu-bar-widget.qml`).
- nixarchy builds its patches with `--fuzz=0` or with asserts, so an
  upstream rewrite fails the build instead of quietly dropping the
  snowflake. Any new patch follows that rule.
- Changes to nixarchy and nixarchy-menu go through their own repos and
  gates. This repo only restores the opt-in and bumps the lock.
- Never build or deploy p510. Build razer on p620
  (`just deploy-via-p620 razer`).

## Open questions

1. Should nixarchy-menu stay distro-neutral? If so, nixarchy patches the
   button at build time, like it does for `omarchy.menu`. If not,
   nixarchy-menu draws the snowflake itself. The spec will recommend one.
2. Should the snowflake be the default for every nixarchy user of
   nixarchy-menu, or an option? The default suggestion is always on,
   matching the stock button.
