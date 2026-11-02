# agent-say — speak a short summary when Claude Code or Codex finishes a turn.
#
# Authored in-repo (agent_say.py, stdlib only). It speaks through omarchy-voice,
# so the interpreter is a python env that carries omarchy-voice and its
# dependencies. `omarchyVoice = null` (the pkgs/default.nix default) still
# builds -- speaking just fails at runtime -- so walking customPkgs is safe;
# modules/programs/agent-voice.nix passes the real package through .override.
{ lib
, stdenvNoCC
, makeWrapper
, python3
, pulseaudio
, libnotify
, systemd
, omarchyVoice ? null
}:
let
  # omarchy-voice is an application, which withPackages will not put on the
  # path; take its dependencies instead and add its site-packages by hand.
  deps = lib.optionals (omarchyVoice != null) omarchyVoice.dependencies;
  sitePackages = lib.optionalString (omarchyVoice != null) "${omarchyVoice}/${python3.sitePackages}";
  pythonEnv = python3.withPackages (_: deps);
  testEnv = python3.withPackages (ps: deps ++ [ ps.pytest ]);
in
stdenvNoCC.mkDerivation {
  pname = "agent-say";
  version = "0.1.0";

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm644 ${./agent_say.py} $out/share/agent-say/agent_say.py
    # AGENT_SAY_BIN: the hook starts a transient unit that must not depend on PATH.
    makeWrapper ${pythonEnv}/bin/python $out/bin/agent-say \
      --add-flags "$out/share/agent-say/agent_say.py" \
      --set AGENT_SAY_BIN $out/bin/agent-say \
      --prefix PYTHONPATH : "${sitePackages}" \
      --prefix PATH : ${lib.makeBinPath [ pulseaudio libnotify systemd ]}

    runHook postInstall
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    HOME=$TMPDIR AGENT_SAY_MODULE=${./agent_say.py} \
      ${testEnv}/bin/python -m pytest -q -p no:cacheprovider ${./test_agent_say.py}
    runHook postCheck
  '';

  meta = {
    description = "Spoken summaries of finished Claude Code and Codex turns";
    license = lib.licenses.mit;
    mainProgram = "agent-say";
    platforms = lib.platforms.linux;
  };
}
