# claude-swarm-reaper — kills orphaned and long-idle Claude Code swarm tmux servers.
# Authored in-repo (claude_swarm_reaper.py, stdlib only).
{ lib
, stdenvNoCC
, makeWrapper
, python3
, tmux
}:
let
  testEnv = python3.withPackages (ps: [ ps.pytest ]);
in
stdenvNoCC.mkDerivation {
  pname = "claude-swarm-reaper";
  version = "0.1.0";

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm644 ${./claude_swarm_reaper.py} $out/share/claude-swarm-reaper/claude_swarm_reaper.py
    makeWrapper ${python3}/bin/python $out/bin/claude-swarm-reaper \
      --add-flags "$out/share/claude-swarm-reaper/claude_swarm_reaper.py" \
      --prefix PATH : ${lib.makeBinPath [ tmux ]}

    runHook postInstall
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    REAPER_MODULE=${./claude_swarm_reaper.py} \
      ${testEnv}/bin/python -m pytest -q -p no:cacheprovider ${./test_claude_swarm_reaper.py}
    runHook postCheck
  '';

  meta = {
    description = "Reap orphaned and idle Claude Code swarm tmux servers";
    license = lib.licenses.mit;
    mainProgram = "claude-swarm-reaper";
    platforms = lib.platforms.linux;
  };
}
