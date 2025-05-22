{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs,
  makeWrapper,
  writeShellScriptBin,
}: let
  # Main package
  claudeCode = buildNpmPackage rec {
    pname = "claude-code";
    version = "1.0.1";

    src = fetchurl {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-1iKDtTE+cHXMW/3zxfsNFjMGMxJlIBzGEXWtTfQfSMM=";
    };

    npmDepsHash = "sha256-fuJE/YTd9apAd1cooxgHQwPda5js44EmSfjuRVPbKdM=";

    inherit nodejs;

    makeCacheWritable = true;

    postPatch = ''
      if [ -f "${./claude-code/package-lock.json}" ]; then
        echo "Using vendored package-lock.json"
        cp "${./claude-code/package-lock.json}" ./package-lock.json
      else
        echo "No vendored package-lock.json found, creating a minimal one"
        exit 1
      fi
    '';

    dontNpmBuild = true;
    dontNpmInstall = true;

    nativeBuildInputs = [makeWrapper];

    # Create a custom installation phase to handle the package organization
    installPhase = ''
      # Create a directory for the lib files
      mkdir -p $out/lib/node_modules/@anthropic-ai/claude-code

      # Copy all package files to the lib directory
      cp -a . $out/lib/node_modules/@anthropic-ai/claude-code/

      # Create bin directory
      mkdir -p $out/bin

      # Create a wrapper script that points to the actual CLI script
      makeWrapper ${nodejs}/bin/node $out/bin/claude-code \
        --add-flags "$out/lib/node_modules/@anthropic-ai/claude-code/cli.mjs"
    '';

    meta = with lib; {
      description = "Claude Code CLI tool";
      homepage = "https://www.anthropic.com/claude-code";
      mainProgram = "claude-code";
    };
  };

  # Helper script to update the package-lock.json file
  #
  # Build with `nix build .#claude-code.updateScript`
  updateScript = writeShellScriptBin "update-claude-code-lock" ''
    #!/usr/bin/env bash
    set -e

    if [ $# -ne 1 ]; then
      echo "Usage: update-claude-code-lock <version>"
      echo "Example: update-claude-code-lock 1.0.1"
      exit 1
    fi

    VERSION="$1"
    TEMP_DIR=$(mktemp -d)
    LOCK_DIR="$PWD/packages/claude-code"

    echo "Creating $LOCK_DIR if it doesn't exist..."
    mkdir -p "$LOCK_DIR"

    echo "Downloading claude-code version $VERSION..."
    curl -L "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-$VERSION.tgz" -o "$TEMP_DIR/claude-code.tgz"

    echo "Extracting tarball..."
    mkdir -p "$TEMP_DIR/extract"
    tar -xzf "$TEMP_DIR/claude-code.tgz" -C "$TEMP_DIR/extract"

    echo "Generating package-lock.json..."
    cd "$TEMP_DIR/extract/package"
    ${nodejs}/bin/npm install --package-lock-only --ignore-scripts

    echo "Copying package-lock.json to $LOCK_DIR..."
    cp package-lock.json "$LOCK_DIR/"

    echo "Cleaning up..."
    rm -rf "$TEMP_DIR"

    echo "Done. Package lock file updated at $LOCK_DIR/package-lock.json"
    echo "You may need to update the npmDepsHash in your claude-code.nix file."
    echo "Use: prefetch-npm-deps $LOCK_DIR/package-lock.json"
  '';
in
  # Return both the package and the update script
  claudeCode
  // {
    updateScript = updateScript;
    passthru =
      (claudeCode.passthru or {})
      // {
        inherit updateScript;
      };
  }
