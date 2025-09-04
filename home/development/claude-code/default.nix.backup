{ lib
, buildNpmPackage
, fetchurl
, nodejs
, makeWrapper
, writeShellScriptBin
,
}:
let
  claudeCode = buildNpmPackage rec {
    pname = "claude-code";
    version = "1.0.103";

    src = fetchurl {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-0t19XKqOor+H/zrBD9r3US7S917uWvfu4l85D0p8WjQ=";
    };

    npmDepsHash = "sha256-pIjMHIK+6nHI+ZtSsfy6coXRI+6+2w0y9g7VflZGTuc=";

    inherit nodejs;

    makeCacheWritable = true;

    postPatch = ''
      if [ -f "${./package-lock.json}" ]; then
        echo "Using vendored package-lock.json"
        cp "${./package-lock.json}" ./package-lock.json
      else
        echo "No vendored package-lock.json found, creating a minimal one"
        echo '{"lockfileVersion": 1}' > ./package-lock.json
      fi
    '';

    dontNpmBuild = true;

    nativeBuildInputs = [ makeWrapper ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/node_modules/@anthropic-ai/claude-code

      # Debug: List what we have in the source
      echo "=== Source contents ==="
      ls -la

      # Copy from package subdirectory (npm tarballs extract to package/)
      if [ -d "package" ]; then
        echo "=== Package directory contents ==="
        ls -la package/
        cp -r package/* $out/lib/node_modules/@anthropic-ai/claude-code/
      else
        echo "No package directory found, copying current directory"
        cp -r . $out/lib/node_modules/@anthropic-ai/claude-code/
      fi

      # Debug: Check what we installed
      echo "=== Installed contents ==="
      ls -la $out/lib/node_modules/@anthropic-ai/claude-code/

      # Find the actual CLI entry point
      CLI_FILE=""
      for file in cli.mjs cli.js index.mjs index.js bin/cli.mjs bin/cli.js; do
        if [ -f "$out/lib/node_modules/@anthropic-ai/claude-code/$file" ]; then
          CLI_FILE="$file"
          echo "Found CLI at: $file"
          break
        fi
      done

      if [ -z "$CLI_FILE" ]; then
        echo "ERROR: Could not find CLI entry point"
        echo "Available files:"
        find $out/lib/node_modules/@anthropic-ai/claude-code/ -type f -name "*.js" -o -name "*.mjs"
        # Create a simple wrapper anyway
        CLI_FILE="index.js"
      fi

      mkdir -p $out/bin
      makeWrapper ${nodejs}/bin/node $out/bin/claude \
        --add-flags "$out/lib/node_modules/@anthropic-ai/claude-code/$CLI_FILE"

      runHook postInstall
    '';

    meta = with lib; {
      description = "Claude Code CLI tool";
      homepage = "https://github.com/anthropics/claude-code";
      license = licenses.mit;
      maintainers = [ ];
      platforms = platforms.all;
    };
  };

  updateScript = writeShellScriptBin "update-claude-code-lock" ''
    #!/usr/bin/env bash
    set -e

    if [ $# -ne 1 ]; then
      echo "Usage: $0 <version>"
      exit 1
    fi

    VERSION="$1"
    TEMP_DIR=$(mktemp -d)
    LOCK_DIR="$PWD/home/development/claude-code"

    echo "Creating $LOCK_DIR if it doesn't exist..."
    mkdir -p "$LOCK_DIR"

    echo "Downloading claude-code version $VERSION..."
    curl -L "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-$VERSION.tgz" -o "$TEMP_DIR/claude-code.tgz"

    echo "Extracting tarball..."
    tar -xzf "$TEMP_DIR/claude-code.tgz" -C "$TEMP_DIR"

    echo "Copying package-lock.json if it exists..."
    if [ -f "$TEMP_DIR/package/package-lock.json" ]; then
      cp "$TEMP_DIR/package/package-lock.json" "$LOCK_DIR/"
      echo "Updated package-lock.json"
    else
      echo "No package-lock.json found in tarball"
    fi

    echo "Use: nix run nixpkgs#prefetch-npm-deps -- $LOCK_DIR/package-lock.json"

    # Cleanup
    rm -rf "$TEMP_DIR"
  '';
in
claudeCode
  // {
  inherit updateScript;
}
