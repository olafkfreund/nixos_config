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
#
# What this module does NOT do (yet):
#   - The full palette override. Dark.Builder/v1/palette is a Dark((...))
#     tagged enum with ~30 named colour fields (bright_red, accent_blue,
#     gray_1..N, extended_warm_grey, ...). Without writing it, COSMIC's
#     own default palette stays in use and base16 only influences the
#     accent. See issue #431 for follow-up to add the full palette.
#
# Note: cosmic-comp reads these files at session start. Changes require
# a logout/login (or full reboot) before taking effect.
let
  inherit (lib) mkDefault stringToCharacters toLower;

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

  # base0D = primary accent in base16 conventions (blue family in gruvbox).
  accent = hexToRgb config.lib.stylix.colors.base0D;
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
  };
}
