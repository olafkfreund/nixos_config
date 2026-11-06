{ lib
, stdenvNoCC
, fetchFromGitHub
, bash
, coreutils
, hyprland
, jq
, util-linux
}:
# Exposé (kristofferR/omarchy-expose): window overview for the Omarchy shell.
# Overview.qml runs the two helpers directly, so they need a store bash and PATH.
# Bump against: gh api repos/kristofferR/omarchy-expose/commits --jq '.[0].sha'
stdenvNoCC.mkDerivation {
  pname = "expose-plugin";
  version = "5.0.0-unstable-2026-10-26";

  src = fetchFromGitHub {
    owner = "kristofferR";
    repo = "omarchy-expose";
    rev = "f283002259f5aba75da17b3f5dd4081bddc257f5";
    hash = "sha256-kzs/qxLtQ9AI+6eK4aSY/WrD7br1Rf+Qs8mTKfOxjsQ=";
  };

  dontBuild = true;

  postPatch = ''
    # Upstream defaults the hot corner on. Off unless set in Exposé's settings (#2723).
    substituteInPlace Overview.qml \
      --replace-fail 'root.pluginEntry.hotCornerEnabled !== false' \
                     'root.pluginEntry.hotCornerEnabled === true'

    for f in activate-window background-blur-session; do
      [ "$(head -n 1 "$f")" = '#!/bin/bash' ]
      {
        echo '#!${bash}/bin/bash'
        echo 'export PATH=${lib.makeBinPath [ coreutils hyprland jq util-linux ]}:"$PATH"'
        tail -n +2 "$f"
      } > "$f.new"
      mv "$f.new" "$f"
    done
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r --no-preserve=mode . $out/
    for f in activate-window background-blur-session; do
      chmod +x "$out/$f"
      test -x "$out/$f"
      ${bash}/bin/bash -n "$out/$f"
    done

    runHook postInstall
  '';

  meta = {
    description = "Window overview plugin for the Omarchy shell";
    homepage = "https://github.com/kristofferR/omarchy-expose";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
