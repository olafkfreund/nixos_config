{ config, inputs, pkgs, ... }:
# Close the loop: `omarchy theme set X` -> stylix builds against X.
#
# omarchy-theme-set calls `omarchy-hook theme-set "$THEME_NAME"`, which runs
# every executable in ~/.config/omarchy/hooks/theme-set.d with the theme name
# as $1. The hook below writes that name into nixarchy-theme.nix at the flake
# root, where modules/desktop/stylix-theme.nix reads it.
#
# The file has to live inside the flake because a flake cannot read outside its
# own tree -- the same constraint nixarchy-apply works around by copying
# apps.nix in as nixarchy-apps.nix. It has the same consequence: setting a
# theme leaves the working tree dirty until the change is committed, and nhs
# refuses to start on a dirty tree. The hook rewrites nothing when the name is
# unchanged, so only a real theme change dirties anything.
#
# What this does NOT do is rebuild. Omarchy retints its own 24 files instantly;
# Plymouth, GRUB, the console, fonts and the remaining home-manager targets are
# store artifacts and adopt the new palette at the next `nixos-rebuild`. A
# bootloader cannot re-theme itself at runtime, so that gap is structural.
# GTK, Qt colours and icons follow live through the theme engine (#2370).
let
  user = config.programs.nixarchy.user;
  flakeDir = "${config.users.users.${user}.home}/.config/nixos";

  hook = pkgs.writeShellScript "stylix-follow-omarchy-theme" ''
    set -euo pipefail
    theme="''${1:-}"
    [ -n "$theme" ] || exit 0

    target="${flakeDir}/nixarchy-theme.nix"
    # Absent or unwritable means this is not the machine holding the flake --
    # do nothing rather than fail a theme switch over it.
    [ -f "$target" ] && [ -w "$target" ] || exit 0

    # Unchanged name: leave the file (and the git tree) alone.
    if [ "$(tail -n 1 "$target")" = "\"$theme\"" ]; then
      exit 0
    fi

    tmp=$(mktemp "$target.XXXXXX")
    cat > "$tmp" <<EOF
    # The Omarchy theme the flake builds against. Rewritten by the theme-set
    # hook in hosts/common/nixos/omarchy-stylix-theme.nix on every
    # \`omarchy theme set\`, so the next rebuild carries the same palette into
    # everything Stylix owns and Omarchy cannot reach at runtime -- Plymouth,
    # GRUB, the console, fonts, and the remaining home-manager targets.
    #
    # Edit by switching themes, not by hand: a hand edit is overwritten the
    # next time a theme is set.
    "$theme"
    EOF
    chmod 644 "$tmp"
    mv -f "$tmp" "$target"

    ${pkgs.libnotify}/bin/notify-send -a Omarchy \
      "Theme set to $theme" \
      "Stylix follows on the next rebuild." || true
  '';
in
{
  home-manager.users.${user}.home.file.".config/omarchy/hooks/theme-set.d/10-stylix" = {
    source = hook;
    executable = true;
  };

  # hyprchroma sets gtk-theme to adw-gtk3(-dark); Stylix's HM gtk target used to supply it (#2370).
  environment.systemPackages = [ pkgs.adw-gtk3 ];

  programs.nixarchyThemeEngine.package =
    inputs.nixarchy.inputs.nixarchy-omatheme.packages.${pkgs.stdenv.hostPlatform.system}.hyprchroma.overrideAttrs (old: {
      # shortcut: hyprchroma looks only in Arch's icon dirs; drop once nixarchy-omatheme patches it
      postFixup = (old.postFixup or "") + ''
        for f in $out/lib/hyprchroma/sync-gtk-theme $out/lib/hyprchroma/sync-qt-kde-theme; do
          substituteInPlace "$f" --replace-fail \
            '-d "/usr/share/icons/$value"' \
            '-d "/usr/share/icons/$value" || -d "/run/current-system/sw/share/icons/$value" || -d "/etc/profiles/per-user/${USER:-}/share/icons/$value"'
        done
      '';
    });
}
