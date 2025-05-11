{stdenv}:
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
    license = stdenv.lib.licenses.mit;
    platforms = stdenv.lib.platforms.all;
  };
}
