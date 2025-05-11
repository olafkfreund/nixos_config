{
  lib,
  stdenv,
}:
stdenv.mkDerivation {
  name = "chrome-gruvbox-theme";
  version = "1.0.0";

  src = ../../home/files/chrome-theme;

  installPhase = ''
    mkdir -p $out
    cp -r * $out/
  '';

  meta = {
    description = "Gruvbox Dark theme for Chrome/Chromium";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
