{ lib
, stdenvNoCC
, fetchurl
, unzip
, glib
}:
stdenvNoCC.mkDerivation rec {
  pname = "gnome-ext-slider-percentages";
  version = "1";
  uuid = "slider-percentages@imdarktom";

  src = fetchurl {
    url = "https://extensions.gnome.org/extension-data/slider-percentagesimdarktom.v${version}.shell-extension.zip";
    sha256 = "15n2y7cqpq73zdgrlnac37nbhmh5vc05pxhvlmmanawbzlcnn8kr";
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
    description = "Show percentage labels on GNOME quick-settings sliders";
    homepage = "https://github.com/imdarktom/slider-percentages";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
