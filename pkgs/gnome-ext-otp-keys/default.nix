{ lib
, stdenvNoCC
, fetchurl
, unzip
, glib
}:
stdenvNoCC.mkDerivation rec {
  pname = "gnome-ext-otp-keys";
  version = "33";
  uuid = "otp-keys@osmank3.net";

  src = fetchurl {
    url = "https://extensions.gnome.org/extension-data/otp-keysosmank3.net.v${version}.shell-extension.zip";
    sha256 = "1r0c63g6a1bkw7q151glm865rrcg07wk2lja4kxkq9rnbcxrh7qf";
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
    description = "Show and copy OTP keys from the GNOME top panel";
    homepage = "https://github.com/osmank3/otp-keys";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
