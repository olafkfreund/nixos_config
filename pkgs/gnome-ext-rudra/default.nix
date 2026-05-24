{ lib
, stdenvNoCC
, fetchurl
, unzip
, glib
, jq
}:
stdenvNoCC.mkDerivation rec {
  pname = "gnome-ext-rudra";
  version = "7";
  uuid = "rudra@narkagni";

  src = fetchurl {
    url = "https://extensions.gnome.org/extension-data/rudranarkagni.v${version}.shell-extension.zip";
    sha256 = "0mpbakxs440rbl5h596zxqskva90dbzqg2xqlgm1ll8lb29vapvm";
  };

  nativeBuildInputs = [ unzip glib jq ];

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -d "$out/share/gnome-shell/extensions/${uuid}"
    unzip -q "$src" -d "$out/share/gnome-shell/extensions/${uuid}"

    # GNOME 50 compat patch: the published v7 ZIP's metadata.json declares
    # shell-version up to "49" only, so GNOME Shell silently disables rudra
    # on GNOME 50+. Upstream's master HEAD has already added "50" to the
    # array (https://github.com/NarkAgni/rudra/blob/master/metadata.json)
    # but hasn't pushed a v8 to extensions.gnome.org. Patch the metadata
    # in place until then — drop this block when a newer ZIP with "50"
    # baked in lands upstream.
    meta="$out/share/gnome-shell/extensions/${uuid}/metadata.json"
    jq '.["shell-version"] |= (. + ["50"] | unique)' "$meta" > "$meta.tmp"
    mv "$meta.tmp" "$meta"

    if [ -d "$out/share/gnome-shell/extensions/${uuid}/schemas" ]; then
      glib-compile-schemas "$out/share/gnome-shell/extensions/${uuid}/schemas"
    fi
    runHook postInstall
  '';

  meta = with lib; {
    description = "Lightning-fast keyboard-centric launcher for GNOME Shell";
    homepage = "https://github.com/narkagni/rudra";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
