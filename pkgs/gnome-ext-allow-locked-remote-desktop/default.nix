{ lib
, stdenvNoCC
, fetchurl
, unzip
, glib
}:
stdenvNoCC.mkDerivation rec {
  pname = "gnome-ext-allow-locked-remote-desktop";
  version = "17";
  uuid = "allowlockedremotedesktop@kamens.us";

  src = fetchurl {
    url = "https://extensions.gnome.org/extension-data/allowlockedremotedesktopkamens.us.v${version}.shell-extension.zip";
    sha256 = "16zb7kdlydq5fi50hbpa9kababf1izwpc82kiznmyi4ain9s5h4p";
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
    description = "Allow GNOME remote desktop connections when the screen is locked";
    homepage = "https://github.com/jikamens/allow-locked-remote-desktop";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
