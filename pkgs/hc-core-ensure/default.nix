{ lib
, writeShellApplication
, herdr-core
, systemd
, util-linux
, coreutils
, stdenv
, shellcheck-minimal
, python3
}:

writeShellApplication {
  name = "hc-core-ensure";
  runtimeInputs = [ systemd util-linux coreutils ];
  text = lib.replaceStrings [ "@hc@" ] [ "${herdr-core}/bin/hc" ]
    (builtins.readFile ./hc-core-ensure.sh);
  derivationArgs.nativeBuildInputs = [ python3 util-linux ];
  checkPhase = ''
    runHook preCheck
    target="$out/bin/hc-core-ensure"
    ${stdenv.shellDryRun} "$target"
    ${lib.getExe shellcheck-minimal} "$target"
    bash ${./test.sh} ${./hc-core-ensure.sh}
    runHook postCheck
  '';
}
