{ lib
, stdenvNoCC
, fetchFromGitHub
, makeWrapper
, bun
,
}:
# tmux-palette — Raycast-style command palette for tmux. TypeScript app
# that runs on Bun.
#
# Packaging is trivial because the project's runtime "dependencies" object
# in package.json is empty — Bun executes the TS source directly, no
# node_modules needed. We just copy the source into the store and wrap the
# entry script so it can find `bun` at runtime.
#
# Upstream: https://github.com/eduwass/tmux-palette
stdenvNoCC.mkDerivation {
  pname = "tmux-palette";
  version = "0.2.1";

  src = fetchFromGitHub {
    owner = "eduwass";
    repo = "tmux-palette";
    rev = "v0.2.1";
    hash = "sha256-bVdd8YAFYwob6y5nATcdLC8nzBKdaCDzqZHqyc+04/k=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/tmux-palette $out/bin
    cp -r ./. $out/share/tmux-palette/

    # The shell entry already calculates DIR relative to itself, so it
    # works from any location as long as the layout is preserved. We just
    # need `bun` on PATH at runtime.
    makeWrapper $out/share/tmux-palette/bin/tmux-palette.sh $out/bin/tmux-palette \
      --prefix PATH : ${lib.makeBinPath [ bun ]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Raycast-style command palette for tmux — fast, scriptable, easy to extend";
    homepage = "https://github.com/eduwass/tmux-palette";
    # Upstream repo has no LICENSE file as of v0.2.1; README implies open source
    # (no explicit ToS). Treating as unfree-redistributable until upstream clarifies.
    license = licenses.unfree;
    platforms = platforms.linux;
    mainProgram = "tmux-palette";
  };
}
