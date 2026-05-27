# audiobookbay-automated — JamesRy96/audiobookbay-automated
#
# A small Flask web app that searches AudioBookBay and pushes the chosen
# release (magnet) to a torrent client. On p510 it is wired to the existing
# Transmission daemon (see modules/services/audiobookbay-automated.nix).
#
# Upstream ships only a Dockerfile (no pyproject/setup.py), running
# `python app.py` from the app/ dir. We therefore install app/ into the store
# and wrap a python env that has its runtime deps. Upstream imports
# `deluge_web_client` unconditionally, but that package is not in nixpkgs and
# we only ever use the Transmission code path — so the two deluge imports are
# patched out (the `delugeweb` branches become dead code, never invoked).
{ lib
, stdenvNoCC
, fetchFromGitHub
, python3
, makeWrapper
}:
let
  pythonEnv = python3.withPackages (ps: with ps; [
    flask
    requests
    beautifulsoup4
    qbittorrent-api
    python-dotenv
    transmission-rpc
  ]);
in
stdenvNoCC.mkDerivation {
  pname = "audiobookbay-automated";
  version = "0-unstable-2026-01-23";

  src = fetchFromGitHub {
    owner = "JamesRy96";
    repo = "audiobookbay-automated";
    rev = "b8e252c2cee5ed745aeeaa0574efd31a05973e8e";
    hash = "sha256-fkGHwPwOxCMIdnj6LSbYt5zx61ROCkajLW+FT5SbVhk=";
  };

  nativeBuildInputs = [ makeWrapper ];

  # Drop the unconditional Deluge imports (deluge-web-client is not packaged
  # in nixpkgs and we only use the Transmission download client).
  postPatch = ''
    substituteInPlace app/app.py \
      --replace-fail "from deluge_web_client import DelugeWebClient as delugewebclient" "" \
      --replace-fail "from deluge_web_client import TorrentOptions as delugetorrentoptions" ""
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/audiobookbay-automated
    cp -r app/. $out/share/audiobookbay-automated/

    makeWrapper ${pythonEnv}/bin/python $out/bin/audiobookbay-automated \
      --add-flags "$out/share/audiobookbay-automated/app.py"

    runHook postInstall
  '';

  meta = {
    description = "Web app to search AudioBookBay and send releases to a torrent client";
    homepage = "https://github.com/JamesRy96/audiobookbay-automated";
    license = lib.licenses.mit;
    mainProgram = "audiobookbay-automated";
    platforms = lib.platforms.linux;
  };
}
