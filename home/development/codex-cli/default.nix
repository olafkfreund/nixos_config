{ lib, pkgs, fetchurl, buildNpmPackage, nodejs_22 }:

let
  # Since this package has no npm dependencies, we can use stdenv.mkDerivation instead
  # But to keep it consistent with the npm ecosystem, we'll use buildNpmPackage with minimal deps
  minimalPackageLock = pkgs.writeText "package-lock.json" (builtins.toJSON {
    name = "@openai/codex";
    version = "0.21.0";
    lockfileVersion = 3;
    requires = true;
    packages = {
      "" = {
        name = "@openai/codex";
        version = "0.21.0";
        license = "Apache-2.0";
        bin = {
          codex = "bin/codex.js";
        };
        engines = {
          node = ">=20";
        };
      };
    };
  });
in
buildNpmPackage rec {
  pname = "openai-codex";
  version = "0.21.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@openai/codex/-/codex-${version}.tgz";
    hash = "sha256-4Jm1BGUGvzXQrLF8sIwPAeCNH05orFT39VaR95j/xGE=";
  };

  # Since there are no npm dependencies, use empty hash and force empty cache
  npmDepsHash = "sha256-sCLNbUmCufTErDcHEZjQwTZFZqlSH+U2ekYqEyPyFnQ=";
  forceEmptyCache = true;

  nodejs = nodejs_22;

  # Create the required package-lock.json during patch phase
  postPatch = ''
    cp ${minimalPackageLock} ./package-lock.json
  '';

  # Skip npm audit and funding messages
  npmFlags = [ "--ignore-scripts" "--no-audit" "--no-fund" ];

  # Don't run npm build since this is a pre-compiled package
  dontNpmBuild = true;
  dontNpmInstall = true;

  # OpenAI Codex requires Node.js 22+ and npm 10+
  nativeBuildInputs = with pkgs; [
    nodejs_22
    makeWrapper
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
    makeWrapper ${nodejs_22}/bin/node $out/bin/codex \
      --add-flags "$out/lib/node_modules/@openai/codex/bin/codex.js"

    # Create convenience aliases
    makeWrapper ${nodejs_22}/bin/node $out/bin/codex-cli \
      --add-flags "$out/lib/node_modules/@openai/codex/bin/codex.js"

    # Make the native binaries executable
    chmod +x $out/lib/node_modules/@openai/codex/bin/codex-*

    runHook postInstall
  '';

  # Metadata for the package
  meta = with lib; {
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
    license = licenses.asl20; # Apache-2.0 License
    maintainers = with maintainers; [ ]; # Add maintainer when contributed upstream
    platforms = platforms.all;
    mainProgram = "codex-cli";
  };
}
