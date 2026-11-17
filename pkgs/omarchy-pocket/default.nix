{ lib
, stdenvNoCC
, fetchFromGitHub
}:
# Pocket (jrmmhm/omarchy-pocket): hides bar widgets behind one mark, shown on hover.
# Bump against: gh api repos/jrmmhm/omarchy-pocket/tags --jq '.[0]'
stdenvNoCC.mkDerivation {
  pname = "omarchy-pocket";
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "jrmmhm";
    repo = "omarchy-pocket";
    rev = "ce39d55efc39909a8f4f9cfd9bc04712cba3280d";
    hash = "sha256-UaRWQCQ3Kdum0F0bLJ2qi8yH5vcnFIPkyNByc24KLqg=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/omarchy-pocket
    cp -r . $out/share/omarchy-pocket/plugin
    rm -rf $out/share/omarchy-pocket/plugin/{.github,tests,docs}
    runHook postInstall
  '';

  meta = {
    description = "Omarchy bar plugin that hides widgets behind one mark until hovered";
    homepage = "https://github.com/jrmmhm/omarchy-pocket";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
