{ lib
, buildNpmPackage
, fetchurl
, nodejs
, makeWrapper
}:

buildNpmPackage rec {
  pname = "claude-code-router";
  version = "1.0.66";

  src = fetchurl {
    url = "https://registry.npmjs.org/@musistudio/claude-code-router/-/claude-code-router-${version}.tgz";
    hash = "sha256-WHb3i0rJhJq8BiMGZEX2oKZoFdM5ct1iKb9aJhtcfs8=";
  };

  npmDepsHash = "sha256-INS9Ove2/ZABIm0GEk7SD8m7TkHdntcxCWnOtwb4MT0=";

  inherit nodejs;

  makeCacheWritable = true;

  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    # Copy vendored package-lock.json
    cp "${./package-lock.json}" ./package-lock.json
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/@musistudio/claude-code-router

    # Copy from package subdirectory if it exists
    if [ -d "package" ]; then
      cp -r package/* $out/lib/node_modules/@musistudio/claude-code-router/
    else
      cp -r . $out/lib/node_modules/@musistudio/claude-code-router/
    fi

    # Create bin directory and wrapper
    mkdir -p $out/bin

    # Find the CLI entry point
    CLI_FILE="dist/index.js"
    if [ ! -f "$out/lib/node_modules/@musistudio/claude-code-router/$CLI_FILE" ]; then
      CLI_FILE="index.js"
    fi

    makeWrapper ${nodejs}/bin/node $out/bin/claude-code-router \
      --add-flags "$out/lib/node_modules/@musistudio/claude-code-router/$CLI_FILE"

    # Create shorter alias
    ln -s $out/bin/claude-code-router $out/bin/ccr

    runHook postInstall
  '';

  meta = with lib; {
    description = "Route Claude Code requests to different AI providers";
    homepage = "https://github.com/musistudio/claude-code-router";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
    mainProgram = "claude-code-router";
  };
}
