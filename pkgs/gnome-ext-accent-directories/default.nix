{ lib
, stdenvNoCC
, fetchurl
, unzip
, glib
}:
stdenvNoCC.mkDerivation rec {
  pname = "gnome-ext-accent-directories";
  version = "17";
  uuid = "accent-directories@taiwbi.com";

  src = fetchurl {
    url = "https://extensions.gnome.org/extension-data/accent-directoriestaiwbi.com.v${version}.shell-extension.zip";
    sha256 = "1l62iacbkbqg0ariqzg634vspbky26myigp5d1f5qyvz27bjw710";
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
    description = "Make GNOME folder icons follow the system accent colour";
    homepage = "https://github.com/taiwbi/gnome-accent-directories";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
