{ config, lib, ... }:
# Centralized COSMIC theme configuration.
#
# COSMIC reads its theme from ~/.config/cosmic/com.system76.CosmicTheme.* —
# unlike GTK/GNOME, none of this is touched by Stylix. Without this module
# COSMIC keeps its default palette regardless of what baseTheme.scheme is
# set to in shared-variables.nix.
#
# What this module does:
#   - Sets dark mode globally (Mode/v1/is_dark = true)
#   - Sets the accent colour from the active base16 scheme's base0D (blue)
#     via Dark.Builder/v1/accent
#   - Writes the full 30-field Dark.Builder/v1/palette RON file, derived
#     from the central base16 colour scheme (Phase 6 of GNOME+Stylix unification)
#   - Writes Dark.Builder/v1/bg_color from base00
#
# CAVEATS (Phase 6 MVP):
#   - Field name list is from cosmic-comp ~v1.0.0-alpha.X (verified live on
#     p620, May 2026). Field names may rename in future cosmic-comp releases —
#     this module would need updating if that happens.
#   - COSMIC reads RON files only at session start. Changes require a
#     logout/login, NOT just a home-manager switch.
#   - The "applied" Dark/v1/* component files (background, button, accent, etc.)
#     are separate per-component files that cosmic-settings re-derives from
#     the Builder when the user opens Appearance. Until then the applied theme
#     stays stale. Opening Appearance once forces re-derivation.
#   - base16 has 4 grey steps; COSMIC palette wants 11 neutrals. Some values
#     are intentionally repeated (neutral_4/neutral_5, neutral_9/neutral_10
#     excepted by pure black/white literals). Full visual parity may need
#     follow-up tweaks after seeing the result on a live session.
#
# Note: cosmic-comp reads these files at session start. Changes require
# a logout/login (or full reboot) before taking effect.
let
  inherit (lib) toLower;

  vars = import ../../../hosts/common/shared-variables.nix;
  colors = config.lib.stylix.colors;

  # base16 hex string ("83a598") -> attrset of {red, green, blue} floats in [0, 1]
  hexCharToInt = c:
    let
      table = {
        "0" = 0;
        "1" = 1;
        "2" = 2;
        "3" = 3;
        "4" = 4;
        "5" = 5;
        "6" = 6;
        "7" = 7;
        "8" = 8;
        "9" = 9;
        "a" = 10;
        "b" = 11;
        "c" = 12;
        "d" = 13;
        "e" = 14;
        "f" = 15;
      };
    in
    table.${toLower c};

  hexPairToFloat = pair:
    let
      hi = hexCharToInt (builtins.substring 0 1 pair);
      lo = hexCharToInt (builtins.substring 1 1 pair);
    in
    (hi * 16 + lo) / 255.0;

  hexToRgb = hex: {
    red = hexPairToFloat (builtins.substring 0 2 hex);
    green = hexPairToFloat (builtins.substring 2 2 hex);
    blue = hexPairToFloat (builtins.substring 4 2 hex);
  };

  # Render a hex colour string as a RON Srgba tuple with alpha 1.0.
  ronColor = hex:
    let
      c = hexToRgb hex;
    in
    "(red: ${toString c.red}, green: ${toString c.green}, blue: ${toString c.blue}, alpha: 1.0)";

  # base0D = primary accent in base16 conventions (blue family in gruvbox).
  accent = hexToRgb colors.base0D;
in
{
  xdg.configFile = {
    # Dark mode toggle (file content is the literal RON value, no quotes)
    "cosmic/com.system76.CosmicTheme.Mode/v1/is_dark".text = "true";

    # Accent colour seed for the dark theme. cosmic-comp regenerates the
    # full Component (hover, pressed, divider, ...) from this Srgb seed.
    "cosmic/com.system76.CosmicTheme.Dark.Builder/v1/accent".text = ''
      Some((
          red: ${toString accent.red},
          green: ${toString accent.green},
          blue: ${toString accent.blue},
      ))
    '';

    # Background colour override — derived from base00 (darkest background).
    # cosmic-comp uses this as the solid colour shown behind all surfaces.
    "cosmic/com.system76.CosmicTheme.Dark.Builder/v1/bg_color".text = ''
      Some(${ronColor colors.base00})
    '';

    # Full 30-field palette for the COSMIC dark theme.
    # Mapping: base16 → COSMIC palette field (see Phase 6 docs for rationale).
    # neutral_0 and neutral_10 are pure black/white literals — no base16 equivalent.
    # neutral_4/neutral_5 and accent_*/ext_* pairs collapse where base16 has fewer
    # hue steps than COSMIC's palette expects.
    "cosmic/com.system76.CosmicTheme.Dark.Builder/v1/palette".text = ''
      Dark((
          name: "${vars.baseTheme.scheme}",
          bright_red: ${ronColor colors.base08},
          bright_green: ${ronColor colors.base0B},
          bright_orange: ${ronColor colors.base09},
          gray_1: ${ronColor colors.base00},
          gray_2: ${ronColor colors.base00},
          neutral_0: ${ronColor "000000"},
          neutral_1: ${ronColor colors.base00},
          neutral_2: ${ronColor colors.base01},
          neutral_3: ${ronColor colors.base02},
          neutral_4: ${ronColor colors.base03},
          neutral_5: ${ronColor colors.base03},
          neutral_6: ${ronColor colors.base04},
          neutral_7: ${ronColor colors.base05},
          neutral_8: ${ronColor colors.base06},
          neutral_9: ${ronColor colors.base07},
          neutral_10: ${ronColor "ffffff"},
          accent_blue: ${ronColor colors.base0D},
          accent_indigo: ${ronColor colors.base0D},
          accent_purple: ${ronColor colors.base0E},
          accent_pink: ${ronColor colors.base0E},
          accent_red: ${ronColor colors.base08},
          accent_orange: ${ronColor colors.base09},
          accent_yellow: ${ronColor colors.base0A},
          accent_green: ${ronColor colors.base0B},
          accent_warm_grey: ${ronColor colors.base04},
          ext_warm_grey: ${ronColor colors.base04},
          ext_orange: ${ronColor colors.base09},
          ext_yellow: ${ronColor colors.base0A},
          ext_blue: ${ronColor colors.base0D},
          ext_purple: ${ronColor colors.base0E},
          ext_pink: ${ronColor colors.base0E},
          ext_indigo: ${ronColor colors.base0D},
      ))
    '';
  };
}
