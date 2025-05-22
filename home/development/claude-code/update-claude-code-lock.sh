#!/usr/bin/env bash
    set -e

    if [ $# -ne 1 ]; then
      echo "Usage: update-claude-code-lock <version>"
      echo "Example: update-claude-code-lock 1.0.1"
      exit 1
    fi

    VERSION="$1"
    TEMP_DIR=$(mktemp -d)
    LOCK_DIR="$PWD"

    echo "Creating $LOCK_DIR if it doesn't exist..."
    mkdir -p "$LOCK_DIR"

    echo "Downloading claude-code version $VERSION..."
    curl -L "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-$VERSION.tgz" -o "$TEMP_DIR/claude-code.tgz"

    echo "Extracting tarball..."
    mkdir -p "$TEMP_DIR/extract"
    tar -xzf "$TEMP_DIR/claude-code.tgz" -C "$TEMP_DIR/extract"

    echo "Generating package-lock.json..."
    cd "$TEMP_DIR/extract/package"
    npm install --package-lock-only --ignore-scripts

    echo "Copying package-lock.json to $LOCK_DIR..."
    cp package-lock.json "$LOCK_DIR/"

    echo "Cleaning up..."
    rm -rf "$TEMP_DIR"

    echo "Done. Package lock file updated at $LOCK_DIR/package-lock.json"
    echo "You may need to update the npmDepsHash in your claude-code.nix file."
    echo "Use: prefetch-npm-deps $LOCK_DIR/package-lock.json"