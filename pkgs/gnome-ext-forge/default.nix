{ lib
, stdenvNoCC
, fetchFromGitHub
, glib
, gettext
}:
# Forge — i3/sway-style tiling and window manager for GNOME Shell.
# Upstream: https://github.com/forge-ext/forge (community fork of the original
# jmmaranan/forge; the UUID `forge@jmmaranan.com` is unchanged for backward
# compat).
#
# Why a master-commit pin (not the latest release tag):
#   The newest tagged release `v49-89` (2025-12-16) predates GNOME 50 and
#   declares `shell-version` only up to `"49"` — GNOME Shell 50+ would
#   silently disable it. Master HEAD has the GNOME 50 + 50.1 metadata
#   addition (and any associated API-shim updates). When upstream cuts a
#   new release with `"50"` baked in, switch back to a release tag.
#
# Why a manual installPhase (not `make install`):
#   The upstream Makefile's `metadata` target runs `git shortlog` to
#   generate `lib/prefs/metadata.js` (a contributors list shown on the
#   Preferences "About" page). The Nix sandbox has no .git directory, so
#   that step would fail. We emit an equivalent empty-list stub instead —
#   the prefs page renders fine, just without the contributor names.
stdenvNoCC.mkDerivation rec {
  pname = "gnome-ext-forge";
  version = "unstable-2026-05-03";
  uuid = "forge@jmmaranan.com";

  src = fetchFromGitHub {
    owner = "forge-ext";
    repo = "forge";
    rev = "0319a7125db1088556b159a69bbec77e111afca7";
    hash = "sha256-IyjHjL1RqxZZZgMnRlmavnae3OqZvRT6aSwKouQRopc=";
  };

  nativeBuildInputs = [ glib gettext ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    target="$out/share/gnome-shell/extensions/${uuid}"
    install -d "$target"

    # Compile gsettings schemas in-place, then copy the whole schemas
    # directory (the compiled file lands beside the .xml inputs).
    glib-compile-schemas schemas

    # Stub the contributors file that the Makefile would generate from
    # `git shortlog`. Empty list — prefs page renders without names.
    install -d lib/prefs
    cat > lib/prefs/metadata.js <<'EOF'
    export const developers = Object.entries([].reduce((acc, x) => ({ ...acc, [x.email]: acc[x.email] ?? x.name }), {})).map(([email, name]) => name + ' <' + email + '>');
    EOF

    # Compile translation catalogs (best-effort — translations are
    # nice-to-have, not load-blocking).
    if [ -d po ]; then
      for po in po/*.po; do
        [ -e "$po" ] || continue
        name=$(basename "$po" .po)
        install -d "$target/locale/$name/LC_MESSAGES"
        msgfmt -c "$po" -o "$target/locale/$name/LC_MESSAGES/forge.mo" || true
      done
    fi

    # Copy the runtime files (mirrors the Makefile's `build` target).
    cp metadata.json "$target/"
    cp ./*.js "$target/"
    cp ./*.css "$target/"
    cp LICENSE "$target/"
    cp -r resources "$target/"
    cp -r schemas "$target/"
    cp -r config "$target/"
    cp -r lib "$target/"

    runHook postInstall
  '';

  meta = with lib; {
    description = "i3/sway-style tiling and window manager for GNOME Shell";
    longDescription = ''
      Forge provides tree-based tiling with vertical and horizontal split
      containers similar to i3-wm and sway-wm, plus Vim-like keybindings
      for navigating, swapping, and moving windows in the containers.
      Works on both X11 and Wayland.
    '';
    homepage = "https://github.com/forge-ext/forge";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
