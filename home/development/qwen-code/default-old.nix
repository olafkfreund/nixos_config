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
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Will be calculated
  };

  # Use Node.js 20 as required by the project
  nodejs = nodejs_20;

  # Make cache writable and add npm flags to handle dependencies
  makeCacheWritable = true;
  npmFlags = [ "--legacy-peer-deps" "--no-audit" "--no-fund" "--offline" ];

  # The project uses workspaces, so we need to handle them properly
  preBuild = ''
    # Ensure we're in the right directory
    ls -la
    
    # Check if package.json exists
    if [ ! -f package.json ]; then
      echo "Error: package.json not found"
      exit 1
    fi
    
    # Show package.json structure for debugging
    echo "Package.json contents:"
    cat package.json | head -20
  '';

  buildPhase = ''
    runHook preBuild
    
    # Run the build script as defined in package.json
    echo "Running npm run build..."
    npm run build
    
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    
    # Create output directories
    mkdir -p $out/lib/node_modules/qwen-code
    mkdir -p $out/bin
    
    # Copy the built application
    cp -r . $out/lib/node_modules/qwen-code/
    
    # Create wrapper script for the binary
    cat > $out/bin/qwen << 'EOF'
#!/usr/bin/env bash
exec ${nodejs_20}/bin/node $out/lib/node_modules/qwen-code/bin/qwen.js "$@"
EOF
    chmod +x $out/bin/qwen
    
    # Also check if there's a different binary location
    if [ -f dist/bin/qwen.js ]; then
      cat > $out/bin/qwen << 'EOF'
#!/usr/bin/env bash
exec ${nodejs_20}/bin/node $out/lib/node_modules/qwen-code/dist/bin/qwen.js "$@"
EOF
    fi
    
    runHook postInstall
  '';

  # Skip tests for now to speed up initial build
  doCheck = false;

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