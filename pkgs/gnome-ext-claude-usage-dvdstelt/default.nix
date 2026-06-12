{ lib
, stdenvNoCC
, fetchurl
, unzip
, glib
}:
# Claude Code Usage Monitor (dvdstelt's variant — claude-usage@dvdstelt.github.io).
# This is the one actually installed; it replaces the older
# claude-code-usage@haletran.com (gnome-ext-claude-code-usage).
stdenvNoCC.mkDerivation rec {
  pname = "gnome-ext-claude-usage-dvdstelt";
  version = "5";
  uuid = "claude-usage@dvdstelt.github.io";

  src = fetchurl {
    url = "https://extensions.gnome.org/extension-data/claude-usagedvdstelt.github.io.v${version}.shell-extension.zip";
    sha256 = "15138qmh8j814nj6n853f65f8vla1v5qkh95yy60ybhnlnh5jd2h";
  };

  nativeBuildInputs = [ unzip glib ];

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -d "$out/share/gnome-shell/extensions/${uuid}"
    unzip -q "$src" -d "$out/share/gnome-shell/extensions/${uuid}"
    if [ -d "$out/share/gnome-shell/extensions/${uuid}/schemas" ]; then
      glib-compile-schemas "$out/share/gnome-shell/extensions/${uuid}/schemas"
    fi
    runHook postInstall
  '';

  meta = with lib; {
    description = "Show Claude Code token/usage stats in the GNOME top panel";
    homepage = "https://github.com/dvdstelt/claude-usage";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
