# Theming (Stylix)

## The problem

A consistent look across a desktop means keeping colours in sync across the
compositor, terminals, editors, GTK/Qt, and every applet. Maintaining those
palettes by hand guarantees they drift.

## The solution

Theming is centralised through **Stylix** using a single **base16** palette.
Every surface derives its colours from `config.lib.stylix.colors` rather than
hard-coding hex values.

The shared theme is defined once in `hosts/common/shared-variables.nix`:

```nix
baseTheme = {
  scheme = "gruvbox-dark";
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
- **COSMIC** — a full RON palette (all 30 fields) is written from the same
  source, so the COSMIC desktop matches everything else.

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

## Per-host wallpaper

The base theme carries a single wallpaper. Hosts may override it in their
`variables.nix`; the mechanism is intentionally minimal because the rest of the
palette is shared.
