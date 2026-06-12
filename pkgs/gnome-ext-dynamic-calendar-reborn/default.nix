{ lib
, stdenvNoCC
, fetchurl
, unzip
, glib
}:
stdenvNoCC.mkDerivation rec {
  pname = "gnome-ext-dynamic-calendar-reborn";
  version = "6";
  uuid = "dynamic-calendar-and-clocks-icons-reborn@thecalamityjoe87.github.com";

  src = fetchurl {
    url = "https://extensions.gnome.org/extension-data/dynamic-calendar-and-clocks-icons-rebornthecalamityjoe87.github.com.v${version}.shell-extension.zip";
    sha256 = "05ba4h6ysp9zca567dss3qfphrn69x1qbcsi25fkhr78gyfhwazj";
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
    description = "Dynamic date/clock/weather panel icons that update live (Reborn fork)";
    homepage = "https://github.com/thecalamityjoe87/dynamic-calendar-and-clocks-icons-reborn";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
