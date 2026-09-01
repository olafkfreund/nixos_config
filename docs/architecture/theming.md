# Theming (Stylix)

Last Updated: 2026-09-01

## The problem

A consistent look across a desktop means keeping colours in sync across the
compositor, terminals, editors, GTK/Qt, and every applet. Maintaining those
palettes by hand guarantees they drift.

## The solution

Theming is centralised through **Stylix** using a single **base16** palette.
Every surface derives its colours from `config.lib.stylix.colors` rather than
hard-coding hex values.

## Where the palette comes from

The **active Omarchy theme is the source of truth for colours.**
`modules/desktop/stylix-theme.nix` reads the theme name from
`nixarchy-theme.nix` at the flake root, loads that theme's `colors.toml` out of
the Nixarchy package, maps its named roles onto the sixteen base16 slots and
hands the result to Stylix.

```text
omarchy theme set X
  ├── retints the 24 files Omarchy owns          → immediately
  └── theme-set.d hook writes X to nixarchy-theme.nix
        └── stylix-theme.nix → Stylix → Plymouth, GRUB, console,
            GTK, Qt, fonts, home-manager targets   → next rebuild
```

Three consequences:

- Everything Omarchy cannot reach at runtime follows at the **next rebuild**,
  not instantly.
- Switching a theme leaves the tree dirty, and `nhs` refuses a dirty tree.
- p510 follows the same palette as the workstations, because `inputs.nixarchy`
  is flake-wide.

Omarchy's `colors.toml` is a named-role palette rather than base16, but its roles
cover all sixteen slots one-for-one. Three stock themes (`last-horizon`,
`solitude`, `white`) ship no `orange` or `brown`, so `base09` and `base0F` fall
back to yellow and muted rather than failing evaluation.

!!! danger "Reach the package through `inputs`"
    Use `inputs.nixarchy`, never `config.programs.nixarchy.package`. Nixarchy
    consumes Stylix, so reading its config from the module that *defines*
    `stylix.base16Scheme` closes the module fixpoint and evaluation dies with
    infinite recursion.

If the theme name is not present in the package — a user theme under
`~/.config/omarchy/themes/`, which the flake cannot see — the build falls back to
the checked-in YAML scheme rather than failing.

## The fallback theme

The fallback theme is defined once in `hosts/common/shared-variables.nix`:

```nix
baseTheme = {
  scheme = "alien-hud";
  wallpaper = ../../assets/wallpapers/amdgruvorange.png;
  cursor = { name = "Bibata-Modern-Classic"; size = 16; };
  font = {
    mono = "Adwaita Mono";
    sans = "Noto Sans";
    serif = "Noto Serif";
  };
  opacity = { desktop = 1.0; terminal = 1.0; popups = 1.0; };
};
```

## What derives from the palette

Surfaces that cannot consume Stylix automatically are wired to it explicitly:

- **GNOME Terminal** and **Zellij** — colours generated from
  `config.lib.stylix.colors`.
- **Plymouth, GRUB and the Linux console** — themed through Stylix, which is
  the only way they can follow Omarchy at all.
- **GTK and Qt**, fonts, cursor and the icon theme (Papirus, recoloured).
- **COSMIC** — a full RON palette (all 30 fields) is written from the same
  source. COSMIC itself is parked (`desktop.cosmic.enable = false` on every
  host), but the writer is kept wired for an easy re-enable.

Because they all read one palette, changing `scheme` re-themes the entire stack
in a single rebuild.

!!! note "nix-colors removed"
    An earlier setup used a standalone `nix-colors` input. It was removed in
    favour of deriving everything from Stylix directly — one source of truth,
    one dependency fewer.

## Opacity

Terminal and popup opacity are pinned to `1.0`. Transparency was disabled
deliberately: it caused rendering issues under COSMIC/GTK. The structure is kept
so it can be re-enabled per host if a future desktop handles it cleanly.

Omarchy manages its own window opacity and blur through
`~/.config/hypr/`; those are runtime settings and are not driven from here.

## Per-host wallpaper

The base theme carries a single wallpaper. Hosts may override it in their
`variables.nix`; the mechanism is intentionally minimal because the rest of the
palette is shared.

See also: [Desktop (Nixarchy / Omarchy on Hyprland)](desktop.md).
