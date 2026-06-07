{ lib
, stdenvNoCC
, fetchFromGitHub
, makeWrapper
, python3
, jq
, fzf
, tmux
,
}:
# tmux-ccm — attention manager for parallel Claude Code sessions.
# bash + Python tmux plugin: one tmux window per project, live PERMIT/BUSY/
# IDLE state detection per claude pane, popup dashboard, cross-project send.
#
# ccm.tmux (loaded by tmux as the plugin entry) and the ccm launcher resolve
# their support files relative to $BASH_SOURCE, so the whole tree must live
# at a single nix-store path with the original layout preserved. We copy it
# under share/tmux-plugins/tmux-ccm/ (the layout home-manager's tmux module
# expects) and wrap ccm into bin/ for CLI use outside the tmux popup.
#
# Wrapping is load-bearing for the popup case: `display-popup -E "ccm ..."`
# spawns a fresh shell that does NOT inherit the user's PATH, so python3/jq/
# fzf must be reachable via the wrapper itself. Same pattern as
# pkgs/tmux-palette/default.nix.
#
# Upstream: https://github.com/yohasebe/tmux-ccm
stdenvNoCC.mkDerivation rec {
  pname = "tmux-ccm";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "yohasebe";
    repo = "tmux-ccm";
    rev = "v${version}";
    hash = "sha256-sQO4NhlSChW34zw5AyhodSFxeWbXA1pC6ETNG5eQtc4=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/tmux-plugins/tmux-ccm $out/bin
    cp -r ./. $out/share/tmux-plugins/tmux-ccm/

    makeWrapper $out/share/tmux-plugins/tmux-ccm/ccm $out/bin/ccm \
      --prefix PATH : ${lib.makeBinPath [ python3 jq fzf tmux ]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Attention manager for parallel Claude Code sessions — tmux plugin with live state detection, dashboard, and cross-project messaging";
    homepage = "https://github.com/yohasebe/tmux-ccm";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "ccm";
  };
}
