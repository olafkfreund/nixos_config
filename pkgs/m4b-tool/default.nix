# m4b-tool — sandreas/m4b-tool
#
# PHP CLI that merges/splits/chapterizes audiobooks into tagged .m4b files.
# Distributed as a self-contained .phar; we fetch the release phar and wrap
# it with PHP plus the runtime tools it shells out to (ffmpeg for decode,
# fdkaac for high-quality AAC, mp4v2's mp4chaps/mp4art for chapters/cover).
{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, php
, ffmpeg
, fdk-aac-encoder
, mp4v2
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "m4b-tool";
  version = "0.5.2";

  src = fetchurl {
    url = "https://github.com/sandreas/m4b-tool/releases/download/v${finalAttrs.version}/m4b-tool.phar";
    hash = "sha256-o+qbgaTozhDsyFwfxxLJgromIvLtAxj7VY2t+tSlkPo=";
  };

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm644 $src $out/share/m4b-tool/m4b-tool.phar
    makeWrapper ${lib.getExe php} $out/bin/m4b-tool \
      --add-flags "$out/share/m4b-tool/m4b-tool.phar" \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg fdk-aac-encoder mp4v2 ]}

    runHook postInstall
  '';

  meta = {
    description = "CLI to merge, split and chapterize audiobooks into tagged M4B";
    homepage = "https://github.com/sandreas/m4b-tool";
    license = lib.licenses.mit;
    mainProgram = "m4b-tool";
    platforms = lib.platforms.linux;
  };
})
