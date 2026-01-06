{ lib, pkgs, fetchurl, buildNpmPackage, nodejs_24 }:

buildNpmPackage rec {
  pname = "openai-codex";
  version = "0.46.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}.tgz";
    hash = "sha256-sh4LQvIvHEnqNFa5g8h7NQsQaIk3VC/ynm9NcgCNUSM=";
  };

  # Version 0.46.0 has no external dependencies
  forceEmptyCache = true;
  npmDepsHash = "sha256-TKQ4ZL68ZsOEnKl/BQBiSUh2UO7yv2dYxp9vDluWIEI=";
  makeCacheWritable = true;

  nodejs = nodejs_24;

  # Copy the required package-lock.json during patch phase
  postPatch = ''
    cp ${./package-lock.json} ./package-lock.json
  '';

  # Skip npm audit and funding messages
  npmFlags = [ "--ignore-scripts" "--no-audit" "--no-fund" ];

  # Don't run npm build since this package has no build script
  dontNpmBuild = true;

  # OpenAI Codex requires Node.js 22+ and npm 10+
  nativeBuildInputs = [
    pkgs.nodejs_24
    pkgs.makeWrapper
  ];

  # Custom install phase since this is a pre-compiled binary package
  installPhase = ''
    runHook preInstall

    # Create output directories
    mkdir -p $out/lib/node_modules/@openai/codex
    mkdir -p $out/bin

    # Copy all package contents
    cp -r . $out/lib/node_modules/@openai/codex/

    # Create the main wrapper
    makeWrapper ${nodejs_24}/bin/node $out/bin/codex \
      --add-flags "$out/lib/node_modules/@openai/codex/bin/codex.js"

    # Create convenience aliases
    makeWrapper ${nodejs_24}/bin/node $out/bin/codex-cli \
      --add-flags "$out/lib/node_modules/@openai/codex/bin/codex.js"

    # Make the native binaries executable (they are in vendor/ subdirectories by arch)
    find $out/lib/node_modules/@openai/codex/vendor -type f -name "codex" -exec chmod +x {} \; 2>/dev/null || true
    find $out/lib/node_modules/@openai/codex/vendor -type f -name "rg" -exec chmod +x {} \; 2>/dev/null || true

    runHook postInstall
  '';

  # Metadata for the package
  meta = {
    description = "OpenAI Codex - Experimental coding agent by OpenAI";
    longDescription = ''
      OpenAI Codex is an experimental coding agent that can help with various programming tasks.
      It supports authentication via ChatGPT account or OpenAI API key.

      Features:
      - Interactive coding assistance
      - Code generation and completion
      - Multi-language support
      - Integration with development workflows

      Requirements:
      - Node.js 22+ and npm 10+
      - 4GB-8GB RAM recommended
      - OpenAI API key or ChatGPT account
    '';
    homepage = "https://github.com/openai/codex";
    changelog = "https://github.com/openai/codex/releases";
    license = lib.licenses.asl20; # Apache-2.0 License
    maintainers = [ ]; # Add maintainer when contributed upstream
    platforms = lib.platforms.all;
    mainProgram = "codex-cli";
  };
}
