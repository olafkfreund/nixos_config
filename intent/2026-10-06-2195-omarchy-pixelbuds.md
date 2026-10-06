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

## Proposed outcome

On p620 and razer, connecting Pixel Buds Pro / Pro 2 shows the case icon in
the bar, with per-bud and case battery and a working listening-mode panel.
The plugin is pinned and rebuilt by Nix, the same way `nixarchy.winvm` is
installed.

## Affected users and systems

- Hosts: p620, razer. Not p510.
- `hosts/{p620,razer}/nixos/nixarchy.nix` (imports) and one new
  `hosts/common/nixos/` plugin file.
- User olafkfreund's Omarchy shell.

## Constraints

- Declarative only: `programs.nixarchy.plugins`, no imperative `omarchy
  plugin add` in `~/.config/omarchy/plugins`.
- Patch the interpreter paths to store paths. Do not add a global
  `/usr/bin/python3` shim.
- Keep the plugin's environment allowlist (`clearEnvironment`) as it is.
- Enabling it in the bar stays manual (`omarchy plugin enable … --section
  right`), as for the other nixarchy plugins.

## Open questions

- Pin with `fetchFromGitHub` + hash, or as a flake input like
  `nixarchy-winvm`? I lean to the flake input so `nhs` bumps it.
