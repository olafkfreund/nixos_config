{ lib
, stdenvNoCC
, fetchurl
, unzip
, glib
}:
stdenvNoCC.mkDerivation rec {
  pname = "gnome-ext-rudra";
  version = "7";
  uuid = "rudra@narkagni";

  src = fetchurl {
    url = "https://extensions.gnome.org/extension-data/rudranarkagni.v${version}.shell-extension.zip";
    sha256 = "0mpbakxs440rbl5h596zxqskva90dbzqg2xqlgm1ll8lb29vapvm";
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
    description = "Lightning-fast keyboard-centric launcher for GNOME Shell";
    homepage = "https://github.com/narkagni/rudra";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
