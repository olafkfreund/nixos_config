{ lib
, stdenvNoCC
, fetchFromGitHub
, python3
, bash
}:
# hello-lock (denonmaryland/hello-lock): Omarchy lock-screen plugin, installed as a store path.
# Bump against: gh api repos/denonmaryland/hello-lock/commits --jq '.[0].sha'
stdenvNoCC.mkDerivation {
  pname = "hello-lock";
  version = "0.5.3";

  src = fetchFromGitHub {
    owner = "denonmaryland";
    repo = "hello-lock";
    rev = "b52d2c2f34cb44e85dd950148ec41696f300c594";
    hash = "sha256-d0B+rrkcgWb9neFGU6SiUQ8/yrMLCf/t7ONIHlJYdxQ=";
  };

  buildInputs = [ python3 bash ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/hello-lock
    cp -r . $out/share/hello-lock/plugin
    rm -rf $out/share/hello-lock/plugin/{docs,tests,preview.png}
    patchShebangs $out/share/hello-lock/plugin/bin
    runHook postInstall
  '';

  meta = {
    description = "Hello-style lock screen plugin for the Omarchy shell";
    homepage = "https://github.com/denonmaryland/hello-lock";
    platforms = lib.platforms.linux;
  };
}
