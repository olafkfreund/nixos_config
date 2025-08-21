{ lib
, stdenv
, fetchzip
, autoPatchelfHook
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
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 opencode $out/bin/opencode

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
