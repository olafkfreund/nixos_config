---
status: draft
issue: 2195
author: olafkfreund
---

# Intent: Pixel Buds plugin in the Omarchy bar on p620 and razer

## Problem

There is no way to see Pixel Buds battery or switch ANC/transparency from the
desktop. The upstream plugin
[rdoupe/omarchy-pixelbuds](https://github.com/rdoupe/omarchy-pixelbuds) does
this, but it is written for Arch: `Service.qml` hardcodes `/usr/bin/python3`
and `/usr/bin/gdbus`. On our hosts envfs resolves `/usr/bin/python3` to a bare
Python 3.14 without PyGObject. Checked on p620: `import gi` fails there.
The bridge would crash on start, so a plain `omarchy plugin add` gives a dead
widget.

The plugin is now forked to
[olafkfreund/nixarchy-pixelbuds](https://github.com/olafkfreund/nixarchy-pixelbuds),
so we can change it ourselves and package it with Nix.

## Proposed outcome

- The fork has a `flake.nix` that builds the plugin folder with working
  interpreter paths. It works on any nixarchy machine, the same shape as
  `nixarchy-microvm` / `nixarchy-winvm` (`packages.default`, `checks`).
- On p620 and razer, connecting Pixel Buds Pro / Pro 2 shows the case icon in
  the bar, with per-bud and case battery and a working listening-mode panel.
- This repo takes the fork as a flake input, so `nhs` bumps it.

## Affected users and systems

- New flake in `olafkfreund/nixarchy-pixelbuds`.
- This repo: `flake.nix` (new input), a new
  `hosts/common/nixos/omarchy-pixelbuds.nix`, and imports in
  `hosts/{p620,razer}/nixos/nixarchy.nix`. Not p510.
- User olafkfreund's Omarchy shell.

## Constraints

- Declarative only, through `programs.nixarchy.plugins`. Nothing imperative
  goes into `~/.config/omarchy/plugins`.
- Use store paths for Python (with PyGObject) and `gdbus`. Do not add a global
  `/usr/bin/python3` shim.
- Keep the plugin's environment allowlist (`clearEnvironment`). Checked: a
  Nix `python3.withPackages (p: [ p.pygobject3 ])` imports Gio/GLib under
  `env -i`.
- Keep the upstream LICENSE/NOTICE attribution (Apache-2.0).
- The fork stays easy to merge from upstream: as few edits to upstream files
  as possible.
- Adding it to the bar stays a one-time manual
  `omarchy plugin enable <id> --section right`, as for the other nixarchy
  plugins.

## Open questions

- Plugin id: keep `io.github.rdoupe.pixelbuds`, or rename to
  `nixarchy.pixelbuds` like our other plugins? Renaming changes the IPC target
  name and diverges from upstream. I lean to keeping it.
- Path fix: patch the store paths in at build time in the flake (no source
  edits, which I lean to), or change `Service.qml` to look the binaries up?
