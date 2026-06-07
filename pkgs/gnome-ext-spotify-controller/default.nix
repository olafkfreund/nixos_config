{ lib
, stdenvNoCC
, fetchurl
, unzip
, glib
}:
stdenvNoCC.mkDerivation rec {
  pname = "gnome-ext-spotify-controller";
  version = "4";
  uuid = "spotify-controller@narkagni";

  src = fetchurl {
    url = "https://extensions.gnome.org/extension-data/spotify-controllernarkagni.v${version}.shell-extension.zip";
    sha256 = "1nhkl3dcvs9b8di7ahh1q2nni02blmkfvnx3i6njm3y3knm44inh";
  };

  nativeBuildInputs = [ unzip glib ];

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -d "$out/share/gnome-shell/extensions/${uuid}"
    unzip -q "$src" -d "$out/share/gnome-shell/extensions/${uuid}"

    # Upstream v4 declares shell-version ["45"…"49"]; GNOME 50 then marks
    # the extension incompatible (red icon). The extension is a panel
    # indicator + MPRIS DBus subscriber for Spotify — no GNOME 50-ABI-
    # breaking surfaces in the usual sense — so widen the declared
    # support to include 50. Remove when upstream publishes a 50-native
    # release.
    META="$out/share/gnome-shell/extensions/${uuid}/metadata.json"
    if ! grep -q '"50"' "$META"; then
      # sed -z reads the whole file as one record, letting the regex span
      # newlines (metadata.json formats shell-version as a multi-line array).
      sed -i -z 's/\("shell-version":[[:space:]]*\[[^]]*\)\]/\1,\n    "50"\n  ]/' "$META"
    fi

    if [ -d "$out/share/gnome-shell/extensions/${uuid}/schemas" ]; then
      glib-compile-schemas "$out/share/gnome-shell/extensions/${uuid}/schemas"
    fi
    runHook postInstall
  '';

  meta = with lib; {
    description = "Feature-rich Spotify controller for GNOME Shell with synced lyrics";
    homepage = "https://github.com/NarkAgni/spotify-controller";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
