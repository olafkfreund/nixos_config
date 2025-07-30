{ lib
, buildNpmPackage
, fetchFromGitHub
, fetchNpmDeps
, nodejs_20
}:

buildNpmPackage rec {
  pname = "qwen-code";
  version = "0.0.1-alpha.8";

  src = fetchFromGitHub {
    owner = "QwenLM";
    repo = "qwen-code";
    rev = "bd0d3479c15aaed9c3d0b36e7a0e90194c5b076d";
    hash = "sha256-3hQGN9R9h1xTu0OAwGecmOxXvdNdU78dh7oOfUPNkkA=";
  };

  npmDeps = fetchNpmDeps {
    inherit src;
    hash = "sha256-3oVrk6nhXuOP6n7HJgyRCFcC7NgZwjh8jkUuC2uNGmo=";
  };

  # Use Node.js 20 as required by the project
  nodejs = nodejs_20;

  # Make cache writable and add necessary npm flags
  makeCacheWritable = true;
  npmFlags = [ "--offline" "--no-audit" "--no-fund" ];

  # Generate git commit info (similar to gemini-cli)
  preConfigure = ''
    mkdir -p packages/generated
    echo "export const GIT_COMMIT_INFO = { commitHash: '${src.rev}' };" > packages/generated/git-commit.ts
  '';

  # Skip tests for now to speed up initial build
  doCheck = false;

  installPhase = ''
    runHook preInstall
    
    # Create lib directory and copy node_modules (like gemini-cli approach)
    mkdir -p "$out/lib"
    cp -r node_modules "$out/lib/"
    
    # Remove any existing workspace packages from node_modules
    rm -rf "$out/lib/node_modules/@qwen-code"
    
    # Copy workspace packages to their proper locations
    mkdir -p "$out/lib/node_modules/@qwen-code"
    
    if [ -d packages/cli ]; then
      cp -r packages/cli "$out/lib/node_modules/@qwen-code/qwen-code"
    fi
    
    if [ -d packages/core ]; then
      cp -r packages/core "$out/lib/node_modules/@qwen-code/qwen-code-core"
    fi
    
    # Create bin directory and link to the main executable
    mkdir -p "$out/bin"
    
    # Find the main entry point after build
    if [ -f "$out/lib/node_modules/@qwen-code/qwen-code/bundle/gemini.js" ]; then
      ln -s "../lib/node_modules/@qwen-code/qwen-code/bundle/gemini.js" "$out/bin/qwen"
    elif [ -f "$out/lib/node_modules/@qwen-code/qwen-code/dist/index.js" ]; then
      ln -s "../lib/node_modules/@qwen-code/qwen-code/dist/index.js" "$out/bin/qwen"
    elif [ -f bundle/gemini.js ]; then
      # Fallback: copy the built bundle directly
      cp bundle/gemini.js "$out/bin/qwen"
      chmod +x "$out/bin/qwen"
      # Add shebang for direct execution
      sed -i '1i#!/usr/bin/env node' "$out/bin/qwen"
    else
      echo "Error: Could not find main entry point"
      find . -name "*.js" -type f | head -10
      exit 1
    fi
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "Command-line AI workflow tool optimized for Qwen3-Coder models";
    longDescription = ''
      Qwen Code is a command-line AI workflow tool adapted from Google Gemini CLI
      and optimized for Qwen3-Coder AI models. It provides code understanding,
      editing capabilities, and workflow automation.
    '';
    homepage = "https://github.com/QwenLM/qwen-code";
    license = licenses.asl20;
    maintainers = with maintainers; [ ]; # Add your name here if desired
    platforms = platforms.all;
    mainProgram = "qwen";
  };
}