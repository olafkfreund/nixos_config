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
(v1.2.0, MIT, upstream `38ca154`, unchanged since 2026-11-15) is an Omarchy
plugin with a service and a bar widget. It publishes a fuller theme,
`omarchy-plus`, which adds:

- the system font, which it takes from fontconfig's `monospace` match;
- Hyprland's corner rounding and borders;
- the shell's popup, menu and tooltip styling;
- the theme's wallpapers inside the app, in four styles.

Its service republishes on theme, font, wallpaper and config changes.

### Blocker: T3 Code version

Upstream requires **T3 Code nightly 0.1.10 from 2026-11-15 or newer**
(`README.md:148-149`). That build accepts 50,000 characters of theme CSS
(`CSS_LIMIT = 50000`, publisher `:39-40`); wallpapers are embedded in the CSS.

| Where | Version |
|---|---|
| p620 (nixpkgs `t3code`) | 0.1.8 |
| Latest stable upstream | 0.1.9 (2026-11-11) |
| 0.1.10 | nightly only, since 2026-11-14 |

An older T3 Code may reject `omarchy-plus.json`, so the plugin cannot be used
on p620 today without a newer T3 Code. Open question 0 covers this.

### What it needs on NixOS

- **Install.** Upstream uses `omarchy plugin add <git url>`. Here plugins come
  from Nix (`programs.nixarchy.plugins.<id>.src`, as for Altscape, Expose and
  llm-index). The plugin id `io.github.jagrat7.omarchy-t3code-plus` is fixed
  in `manifest.json:3` and `BarWidget.qml:9-10`.
- **Publisher.** `bin/t3code-omarchy-plus` starts with `#!/usr/bin/python3`.
  It needs Python 3.11 or later for `tomllib`; all its imports are in the
  standard library.
- **Tools it calls:**
  - `magick`, which needs the AVIF and WebP encoders. Wallpapers are written
    as `avif:-` (`:798`) and pixel art as lossless `webp:-` (`:750`). Without
    AVIF, wallpapers silently disappear (`:803-804`).
  - `fc-match`, `nice`, and `avifenc` (optional).
  - `hyprctl`.
  - Omarchy's own `omarchy-theme-color`, and `omarchy-launch-editor`
    (`Service.qml:73`).
  - `avifenc` and `magick` are found with `shutil.which` (`:606-609, :638,
    :1075`). A string substitution alone would miss them, so the publisher
    needs its `PATH` set.
- **Layout.** The publisher reads `themed/t3code.css.tpl` relative to itself
  (`:32`), and re-runs itself with `sys.executable, __file__, "--warm"`
  (`:1064`).
- **QML.** It uses the sibling components `DripMark.qml` and `StylePreview.qml`,
  `Qt.labs.folderlistmodel`, Quickshell, and the shell's `qs.Commons` and
  `qs.Ui` components.
- **Selection.** It does not select its theme. #2973 does that, through
  `themeId` in `hosts/common/nixos/omarchy-t3code-theme.nix`, and the
  existence check in `t3code-theme-script.nix:45-48`.

## Proposed outcome

On hosts where `programs.nixarchy.apps.t3-code.enable` is true (p620 today),
and once open question 0 is resolved:

- The plugin is installed from a pinned, reviewed commit with upstream's
  runtime layout (`bin/`, `themed/`, all `.qml`), and enabled once. Its bar
  icon can be added; open question 4 covers whether it is placed by default.
- The publisher runs from the Nix store with every tool it needs, and
  publishes `$T3CODE_HOME/userdata/themes/omarchy-plus.json`.
- T3 Code's selected theme is `omarchy-plus`. Until that file exists, it is
  `omarchy` (open question 2), never the built-in theme.

## Affected users and systems

- `olafkfreund` on p620. Razer and p510 are unchanged while `t3-code` is off.
- Files:
  - a new package under `pkgs/`, plus `pkgs/default.nix`;
  - a host module under `hosts/common/nixos/`;
  - #2973's `omarchy-t3code-theme.nix` (`themeId`) and
    `t3code-theme-script.nix` (fallback);
  - possibly a T3 Code override (open question 0).

## Constraints

- Pin a full commit and review all of it before pinning:
  - the publisher;
  - every `.qml` file, since these run inside the shell;
  - `themed/t3code.css.tpl`, for remote `@import` or `url()` loads.
  The repo was one day old when first reviewed.
- Install only what runs. Upstream's `scripts/` (the install and uninstall
  scripts and hooks) and `docs/` are left out. Its `theme-set` and `font-set`
  hooks are not used, because the service already republishes, and upstream
  says to use one or the other.
- Tools from nixpkgs come from store paths, through a wrapped `PATH` that
  covers `shutil.which`. Omarchy's own commands (`omarchy-theme-color`,
  `omarchy-launch-editor`) resolve from the session `PATH`, like #2973's
  `/etc/profiles/per-user/<user>/bin:/run/current-system/sw/bin`. ImageMagick
  must be the full build with AVIF (libheif) and WebP; p620's `magick` has
  both.
- The publisher writes only:
  - under `${T3CODE_HOME:-~/.t3}/userdata/themes/`;
  - under `${XDG_CONFIG_HOME:-~/.config}/omarchy-t3code-plus/`, where the panel
    writes `config.toml`, so it must not be Nix-owned;
  - under `${XDG_STATE_HOME:-~/.local/state}/omarchy-t3code-plus/`, for the
    status and the sharp cache;
  - two lock files in `${XDG_RUNTIME_DIR:-/tmp}`;
  - temporary image files in `$TMPDIR`.
- **Cost.** The publisher runs asynchronously from the service, so theme
  switches don't block. `full-alt` also starts a background `--warm` pass at
  `nice 19` that encodes every wallpaper in the theme. That background CPU
  use must be acceptable on p620.
- **Lifecycle with nixarchy#1803.** #2973's module is meant to be deleted once
  nixarchy#1803 ships. When that happens, the `omarchy-plus` selection has to
  move with it, or #1803 needs a theme-id option. Otherwise two activation
  steps would fight over `defaultTheme`.
- p510 needs the owner's OK before any build or deploy. Nothing changes there
  while `t3-code` is off.

## Open questions

0. **How to get T3 Code ≥ 0.1.10?**
   - (a) Override nixpkgs' `t3code` to a pinned 0.1.10 nightly. That needs
     `overrideAttrs` on `t3code-unwrapped`: version, tag, `src` hash and
     `pnpmDeps` hash. The cost is a source build of an Electron app, nightly
     churn, and possible Electron or pnpm mismatches.
   - (b) Park #2974 until 0.1.10 is stable and in nixpkgs, keeping this intent.
   - (c) Use it on 0.1.8 with a smaller CSS limit. This is unsupported upstream
     and the 0.1.8 limit is unknown. Not recommended.
   - Proposed: (b). Revisit when 0.1.10 is tagged stable.
1. **Default style.** Keep upstream's `full`. The panel owns `config.toml`:
   `save_setting()` writes it, so a Nix-owned file would break the style tiles
   and the tint slider. Both reviewers agree.
2. **Fallback and first selection.**
   - Proposed: #2973's script selects `omarchy` when `themes/${themeId}.json`
     is missing, and checks that the fallback file exists too.
   - Publishing does not select, so T3 Code stays on `omarchy` until the next
     activation, which is the next switch or boot. agy suggests running the
     publisher once from activation when the file is missing. It falls back
     to defaults without Hyprland (`:104-112, :217-231`), so `omarchy-plus`
     would be selected on the first switch. This is for the spec to settle.
3. **`avifenc`.** Include `libavif`. It enables the sharper encoder and the
   warming pass; `full-alt` has an ImageMagick fallback without it
   (`:638-639`). Both reviewers agree.
4. **Bar icon.** Place it on the right of the bar once, so that dragging it off
   sticks, or leave it to `omarchy bar put`? Proposed: once, using the same
   once-per-host marker as `omarchy-enable-once.nix`.
