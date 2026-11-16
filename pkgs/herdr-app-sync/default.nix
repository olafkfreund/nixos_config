{ lib, writeShellApplication, jq, rsync, coreutils, util-linux, systemd }:

writeShellApplication {
  name = "herdr-app-sync";
  runtimeInputs = [ jq rsync coreutils util-linux systemd ];
  text = builtins.readFile ./herdr-app-sync.sh;
  checkPhase = ''
    runHook preCheck
    export PATH="${lib.makeBinPath [ jq coreutils ]}:$PATH"
    bash ${./test.sh} "$out/bin/herdr-app-sync"
    runHook postCheck
  '';
}
