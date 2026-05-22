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
