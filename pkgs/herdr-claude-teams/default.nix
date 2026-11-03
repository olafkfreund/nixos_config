# herdr-claude-teams — runs Claude Code agent teams inside herdr by shimming tmux
# onto herdr's socket API. Fork pinned, plus ownership.patch (teardown only
# touches panes the shim created; respawn waits for the cat placeholder),
# plus teammate-tabs.patch (teammates open as tabs after the lead).
{ lib
, python3Packages
, fetchFromGitHub
, makeWrapper
}:
python3Packages.buildPythonApplication {
  pname = "herdr-claude-teams";
  version = "0.0.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "rameshbaskaran";
    repo = "herdr-claude-teams";
    rev = "984b082357c8cd52d9830fd0a91b7546f4fb0d7b";
    hash = "sha256-mtmKZeB9Zi8zaDzxHKFaUX1VC7T7KumT7rXOH01F0yY=";
  };

  patches = [ ./ownership.patch ./teammate-tabs.patch ];

  build-system = [ python3Packages.hatchling ];
  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [ python3Packages.pytestCheckHook ];

  # needs a live herdr
  disabledTestPaths = [ "tests/test_live_smoke.py" ];

  postInstall = ''
    makeWrapper ${python3Packages.python.interpreter} $out/libexec/herdr-claude-teams/shim/tmux \
      --add-flags "-m herdr_claude_teams.shim" \
      --prefix PYTHONPATH : "$out/${python3Packages.python.sitePackages}"
    wrapProgram $out/bin/herdr-claude-teams \
      --set HERDR_CLAUDE_TEAMS_SHIM_DIR $out/libexec/herdr-claude-teams/shim
  '';

  meta = {
    description = "Run Claude Code agent teams in herdr panes";
    homepage = "https://github.com/rameshbaskaran/herdr-claude-teams";
    license = lib.licenses.mit;
    mainProgram = "herdr-claude-teams";
    platforms = lib.platforms.linux;
  };
}
