{ lib
, stdenvNoCC
, fetchgit
, gtk3
}:
# YAMIS — Yet Another Monochrome Icon Set.
# Freedesktop-spec-compliant monochromatic icon theme with FollowsColorScheme,
# so a single theme name renders correctly under both light and dark
# polarity (Stylix handles the polarity switch via dconf).
#
# Upstream: https://bitbucket.org/dirn-typo/yet-another-monochrome-icon-set
# License: GPL-3.0
# Inherits: Papirus-Dark, breeze-dark, Cosmic, Adwaita, hicolor — so any
# icon YAMIS doesn't ship falls back through that chain. Adwaita is in
# nixpkgs by default, so the fallback never produces missing-icon glyphs;
# Papirus-Dark would improve visual completeness if you ever add it.
#
# Not in nixpkgs (verified 2026-05-24 via mcp-nixos), so packaged here
# alongside the existing custom-icon-set / gnome-ext-* style.
stdenvNoCC.mkDerivation rec {
  pname = "yet-another-monochrome-icons";
  version = "unstable-2026-05-22";

  src = fetchgit {
    url = "https://bitbucket.org/dirn-typo/yet-another-monochrome-icon-set.git";
    rev = "3d9dc63386f35618cd8570767ade43ff0edab7a7";
    hash = "sha256-KzAWx+ls4Y0WzaFIdCjtarkr68/uE9jyeRreLyPcziw=";
  };

  # gtk-update-icon-cache lives in gtk3 — needed so apps don't have to
  # rescan the (large) theme tree on every launch.
  nativeBuildInputs = [ gtk3 ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    target="$out/share/icons/yet-another-monochrome-icon-set"
    install -d "$target"

    # Copy the theme metadata and every freedesktop-spec context directory
    # that's actually present at the repo root.
    cp index.theme "$target/"
    for dir in actions apps categories devices emblems mimetypes places preferences status; do
      [ -d "$dir" ] && cp -r "$dir" "$target/"
    done

    # Build the GTK icon cache so apps don't pay the per-launch scan cost.
    # `|| true` because a missing-cache failure shouldn't fail the build
    # outright — apps fall back to direct directory scanning.
    gtk-update-icon-cache --force --quiet "$target" || true

    runHook postInstall
  '';

  meta = with lib; {
    description = "YAMIS — monochrome icon theme with Papirus-Dark / breeze-dark / Cosmic / Adwaita fallback chain";
    homepage = "https://bitbucket.org/dirn-typo/yet-another-monochrome-icon-set";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
