{ config, lib, pkgs, ... }:
# DankMaterialShell: the shell package, its Alien HUD palette and the
# settings.json merge. Compositor-independent — the per-session config lives in
# ./niri.nix and ./hyprland.nix.
#
# DMS is launched from the compositor startup hooks, NOT via its systemd
# service, which binds to the graphical-session target that GNOME also reaches
# and would spawn a second shell over gnome-shell. Session companion tools
# (wallpaper, idle, night-light) follow the SAME rule.
#
# Theming: DMS reads its palette from its own theme.json, not from Stylix, so
# DankMaterialShell/themes/alienHud/theme.json is generated from
# config.lib.stylix.colors.
#
# The Noctalia shell was removed 2026-08-21 (unused); DMS is now the only shell
# on the niri and Hyprland sessions.
{
  # wl-mirror: mirror an output to a window (niri has no native mirroring).
  # jq: parse the compositor's JSON IPC. wl-screenrec/slurp: HW-encoded recording.
  home.packages = with pkgs; [
    wl-mirror
    jq
    wl-screenrec
    slurp
    swaybg # static wallpaper for niri/labwc (Stylix only themes GNOME's bg)
    # mpvpaper — video/live wallpaper on a wlr-layer-shell surface. Installed
    # but NOT spawned: swaybg is still the startup wallpaper below, and both
    # painting the same output would stack two background layers. To use it,
    # stop swaybg first (`pkill swaybg`) and run
    # `mpvpaper -o "no-audio loop" '*' <video>`.
    mpvpaper
    swayidle # idle → lock / screen-off / (laptop) suspend
    gammastep # night-light / colour temperature by sun position
    wlopm # labwc DPMS off/on (niri has a native power-off-monitors action)
    kanshi # output-profile daemon; per-host profiles are a TODO (niri does
    #         output config natively in config.kdl, so this is mainly for labwc)
    # Screen-recording toggle bound to Mod+Shift+R / Mod+Alt+R. Records the
    # focused output (or a slurp-selected region) to ~/Videos; re-run to stop.
    (writeShellScriptBin "screenrecord" ''
      set -euo pipefail
      out="$HOME/Videos"; mkdir -p "$out"
      if ${procps}/bin/pgrep -x wl-screenrec >/dev/null 2>&1; then
        ${procps}/bin/pkill -INT -x wl-screenrec
        ${libnotify}/bin/notify-send "Screen recording" "Saved to $out"
      else
        f="$out/rec-$(date +%Y%m%d-%H%M%S).mp4"
        if [ "''${1:-}" = "region" ]; then
          geom="$(${slurp}/bin/slurp)" || exit 0
          ${wl-screenrec}/bin/wl-screenrec -g "$geom" -f "$f" &
        else
          # Focused-output lookup is the only compositor-specific bit; labwc and
          # mango have no such IPC, which is why they bind the region variant.
          if [ -n "''${NIRI_SOCKET:-}" ]; then
            name="$(${niri}/bin/niri msg --json focused-output | ${jq}/bin/jq -r .name)"
          else
            name="$(${hyprland}/bin/hyprctl -j activeworkspace | ${jq}/bin/jq -r .monitor)"
          fi
          ${wl-screenrec}/bin/wl-screenrec -o "$name" -f "$f" &
        fi
        ${libnotify}/bin/notify-send "Screen recording" "Recording… Mod+Shift+R to stop"
      fi
    '')
  ];

  # ── DankMaterialShell theme ────────────────────────────────────────────────
  # DMS reads its palette from its own theme.json (NOT from Stylix), so the DMS
  # session would otherwise keep its own palette while niri and the terminals
  # follow Stylix.
  # Same derivation from config.lib.stylix.colors as the Noctalia palette above,
  # so both shells and the compositor cannot drift apart.
  #
  # Schema mirrors the shipped gruvboxMaterial theme: role colours in dark/light,
  # surface colours only inside a `variants` option (DMS ignores surface keys
  # placed directly in `dark`). `outline` is the important one — it draws the
  # hairline edges on every DMS panel, which is what sells the HUD look.
  xdg.configFile."DankMaterialShell/themes/alienHud/theme.json".source =
    let
      inherit (config.lib.stylix) colors;
      c = n: "#${colors.${n}}";
      roles = {
        primary = c "base0B"; # phosphor green
        primaryContainer = c "base03";
        secondary = c "base09"; # amber
        surfaceText = c "base05";
        surfaceVariantText = c "base04";
        backgroundText = c "base05";
        outline = c "base03"; # panel hairlines
        error = c "base08";
        warning = c "base09";
        info = c "base0C";
      };
      surfaces = {
        primaryText = c "base00";
        surface = c "base00";
        surfaceVariant = c "base01";
        surfaceTint = c "base02";
        background = c "base00";
        surfaceContainer = c "base01";
        surfaceContainerHigh = c "base02";
        surfaceContainerHighest = c "base03";
      };
    in
    (pkgs.formats.json { }).generate "dms-alien-hud.json" {
      id = "alienHud";
      name = "Alien HUD";
      version = "1.0.0";
      author = "olafkfreund";
      description = "Weyland-Yutani propulsion-monitor palette, derived from the Stylix base16 scheme";
      dark = roles;
      light = roles; # dark-only fleet; light exists to satisfy the schema
      variants = {
        default = "standard";
        options = [
          {
            id = "standard";
            name = "Standard";
            dark = surfaces;
            light = surfaces;
          }
        ];
      };
    };

  # DMS owns settings.json at runtime (it rewrites the file on every UI change),
  # so it can never be a store symlink. Point the two theme keys at the file
  # above instead — idempotent, and left alone if DMS is not set up yet. The
  # font switch is what makes DMS read as an instrument panel rather than a
  # Material shell; drop the fontFamily line to keep the proportional UI font.
  home.activation.dmsAlienTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.config/DankMaterialShell/settings.json"
    theme="$HOME/.config/DankMaterialShell/themes/alienHud/theme.json"

    if [ -f "$settings" ]; then
      $DRY_RUN_CMD ${pkgs.jq}/bin/jq --arg t "$theme" \
        '.currentThemeName = "custom"
         | .currentThemeCategory = "custom"
         | .customThemeFile = $t
         | .fontFamily = "JetBrainsMono Nerd Font"
         | .monoFontFamily = "JetBrainsMono Nerd Font"' \
        "$settings" > "$settings.tmp" && $DRY_RUN_CMD mv "$settings.tmp" "$settings"
    fi
  '';
}
