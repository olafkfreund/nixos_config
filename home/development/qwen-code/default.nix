# Qwen-Code NixOS Package
# AI-powered coding assistant using Qwen3-Coder models
{ lib
, buildNpmPackage
, fetchFromGitHub
, fetchNpmDeps
, nix-update-script
,
}:

buildNpmPackage (finalAttrs: {
  pname = "qwen-code";
  version = "unstable-2025-07-24";

  src = fetchFromGitHub {
    owner = "sid115";
    repo = "qwen-code";
    rev = "e082e301bf2e779435237aab56927b204ead5d2e";
    hash = "sha256-qX2ssemIt3Ijl9GxCgurcXg5B5ZC2D6cRjGqD9G8Ksg=";
  };

  npmDeps = fetchNpmDeps {
    inherit (finalAttrs) src;
    hash = "sha256-zzF/9V+g3uxZxCGmIIHplDX8IRd2txbLj9lco+pkkWg=";
  };

  buildPhase = ''
    runHook preBuild

    # Generate git commit info and bundle the application
    npm run generate
    npm run bundle

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp -r bundle/* $out/

    # Fix node shebang for NixOS
    substituteInPlace $out/gemini.js \
      --replace '/usr/bin/env node' "$(type -p node)"

    # Create both command variants
    ln -s $out/gemini.js $out/bin/qwen-code
    ln -s $out/gemini.js $out/bin/qwen

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = with lib; {
    description = "AI-powered coding assistant using Qwen3-Coder models";
    longDescription = ''
      Qwen-code is an interactive CLI tool that leverages Qwen3-Coder models
      for code understanding, editing, and workflow automation. It features
      a React-based terminal UI, sandbox execution, file context analysis,
      and comprehensive development assistance capabilities.
    '';
    homepage = "https://github.com/QwenLM/qwen-code";
    license = licenses.asl20;
    maintainers = with maintainers; [ ];
    mainProgram = "qwen-code";
    platforms = platforms.all;
  };
})
