{ lib
, stdenv
, fetchzip
, makeWrapper
, glibc
}:

stdenv.mkDerivation rec {
  pname = "opencode";
  version = "0.5.13";

  src = fetchzip {
    url = "https://github.com/sst/opencode/releases/download/v${version}/opencode-linux-x64.zip";
    hash = "sha256-AbZn0RazdkmzbaOFtMvkMxHmnVsyFnw8IQhocz8BBpA=";
    stripRoot = false;
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    glibc
  ];

  dontPatchELF = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    # Install the binary
    install -Dm755 opencode $out/bin/.opencode-real

    # Create wrapper that adds library paths and handles arguments
    makeWrapper $out/bin/.opencode-real $out/bin/opencode \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ stdenv.cc.cc.lib glibc ]}" \
      --run 'if [ $# -eq 0 ]; then set -- .; fi'

    runHook postInstall
  '';

  meta = with lib; {
    description = "AI coding agent for the terminal";
    homepage = "https://opencode.ai";
    license = licenses.mit;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "opencode";
  };
}
