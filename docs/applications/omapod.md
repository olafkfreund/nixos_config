# omaPOD (podcasts)

omaPOD is a podcast app with an Omarchy bar widget. It is enabled on p620 and razer by
`hosts/common/nixos/omarchy-omapod.nix` (#2977).

## What it installs

- The `omapod` package, its desktop entry and the podcast/OPML link handlers (`programs.omapod.enable`).
- The Home Manager module with an hourly feed refresh (`omapod-refresh.timer`). Automatic downloads are off by
  omaPOD's default, so the refresh only checks feeds; if you turn them on, also turn off "download on battery" in
  omaPOD's settings to keep razer from downloading on battery (omaPOD's default allows it).
- The bar widget, installed by `programs.nixarchy.plugins` and enabled once per host by a post-boot hook. It
  appears after the next login. Turning it off later in Setup > Plugins sticks.
- The key bindings, from a Nix-owned `~/.config/hypr/omapod-binds.lua`. Its `require` line is appended once to
  your `bindings.lua` at activation.

## Keys

| Chord | Action |
| --- | --- |
| `SUPER+CTRL+SHIFT+K` | Toggle play/pause |
| `SUPER+CTRL+SHIFT+COMMA` | Rewind |
| `SUPER+CTRL+SHIFT+PERIOD` | Forward |
| `SUPER+CTRL+SHIFT+N` | Skip |
| `SUPER+CTRL+SHIFT+O` | Show omaPOD |

## Data and removal

The library lives in `~/.local/share/omapod` and `~/.config/omapod`, and stays when omaPOD is removed.
To remove omaPOD, drop the import of `omarchy-omapod.nix` from both hosts. The appended `require` line is
harmless without `omapod-binds.lua` (it runs under `pcall`).

## Hardening exceptions

- **`omapod-refresh.service` and `omapod-settings.service` (Home Manager user units):** Both read and write
  `~/.local/share/omapod` and `~/.config/omapod`. `DynamicUser` and `ProtectHome` would hide that data, and
  `ProtectSystem = "strict"` requires mount namespacing that user units lack. `NoNewPrivileges = true` is kept,
  because omaPOD runs no setuid program.
