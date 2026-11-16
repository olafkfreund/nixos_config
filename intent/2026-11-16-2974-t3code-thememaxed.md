---
status: draft
issue: 2974
author: olafkfreund
---

# Intent: package T3 Code Thememaxed as a Nix Omarchy plugin

## Problem

Since #2973, T3 Code follows the Omarchy theme on p620, but only its colours:
`omarchy-theme-set-t3code` publishes the palette as `themes/omarchy.json`.

[T3 Code Thememaxed](https://github.com/jagrat7/omarchy-t3code-thememaxed)
(v1.2.0, MIT, upstream `38ca154`) is an Omarchy plugin, with a service and a
bar widget. It publishes a fuller theme, `omarchy-plus`, which adds:

- the system font;
- Hyprland's corner rounding and active and inactive borders;
- the shell's popup, menu and tooltip styling;
- the theme's wallpapers inside the app, in four styles: `minimal`, `full`,
  `max` and `full-alt`.

Its service republishes on every theme switch, font change and edit to its own
config file.

It cannot be installed on Nixarchy as it is:

- Upstream installs it with `omarchy plugin add <git url>`, which clones it into
  `~/.config/omarchy/plugins`. On this config, plugins come from Nix
  (`programs.nixarchy.plugins.<id>.src`), like Altscape, Expose and llm-index.
- Its publisher, `bin/t3code-omarchy-plus` (1144 lines), starts with
  `#!/usr/bin/python3`, which does not exist on NixOS. The service runs it
  directly (`Service.qml:16`).
- The publisher calls tools by bare name:
  - `magick` and `fc-match`;
  - `hyprctl` and `omarchy-theme-color`;
  - `nice`;
  - `avifenc`, which is optional.
- The panel calls `omarchy-launch-editor`. Python 3.11 or later is needed for
  `tomllib`.
- It does not select its theme. Its README says to pick it once in T3 Code's
  settings. #2973 does the selecting, through its `themeId` binding.

## Proposed outcome

On hosts where `programs.nixarchy.apps.t3-code.enable` is true (p620 today):

- The plugin `io.github.jagrat7.omarchy-t3code-plus` is installed from a pinned,
  reviewed upstream commit and enabled once. Its bar icon is available.
- Its publisher runs from the Nix store with every tool it needs, and publishes
  `~/.t3/userdata/themes/omarchy-plus.json` on theme, font and config changes.
- T3 Code's selected theme is `omarchy-plus`, through #2973's `themeId`.
- If `omarchy-plus.json` has not been published yet, T3 Code still gets a
  themed look instead of its built-in theme. Open question 2 covers how.

## Affected users and systems

- `olafkfreund` on p620, where T3 Code is enabled.
- Razer and p510: unchanged while `t3-code` is off there.
- Files:
  - a new package under `pkgs/`, with an entry in `pkgs/default.nix`;
  - a host module under `hosts/common/nixos/`;
  - `hosts/common/nixos/omarchy-t3code-theme.nix` (#2973), for `themeId`.

## Constraints

- Pin a full commit hash and review the upstream code before pinning. The repo
  was one day old when reviewed: all its commits are from 2026-11-15, by one
  author.
- No `/usr` paths or bare tool lookups in what is installed. Tools come from
  store paths, as in `pkgs/altscape`.
- Do not run upstream's `scripts/install.sh`, and do not add its `theme-set` or
  `font-set` hooks. The plugin service does the republishing, and upstream
  says to use one or the other.
- The publisher writes only under `~/.t3/userdata/themes/`,
  `~/.config/omarchy-t3code-plus/` and `~/.local/state/omarchy-t3code-plus/`,
  and takes its lock in `$XDG_RUNTIME_DIR`. Nothing under `~/.t3` is owned by
  Nix.
- Cost: every theme switch re-encodes wallpapers, and some slow `avifenc`
  passes take about 1 s each. Theme switches must stay responsive.
- p510 needs the owner's OK before any build or deploy. Nothing changes there
  while `t3-code` is off.

## Open questions

1. **Default style.**
   - Upstream's default is `full`: a wallpaper in the sidebar header and a
     random theme wallpaper behind the conversation.
   - Proposed: keep `full`.
   - Should the config set the style declaratively? That would be a Nix-owned
     `config.toml`, which conflicts with the panel's own style picker.
     Proposed: no; leave the style to the panel.
2. **Fallback when `omarchy-plus.json` is missing.**
   - The plugin only publishes once the shell is running. On a fresh install
     or the first boot after enabling, #2973's activation step finds no
     `omarchy-plus.json`, logs, and selects nothing until the next boot.
   - Proposed: #2973's script selects `omarchy` when `themeId`'s file does not
     exist. The next activation then moves T3 Code to `omarchy-plus` once the
     plugin has published.
   - The alternative is to accept one boot on the built-in theme.
3. **`avifenc`.** It is optional upstream and only used by `full-alt`, which
   upstream marks "not recommended". Proposed: include `libavif` anyway; it is
   small, and every style works then.
