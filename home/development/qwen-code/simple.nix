{ lib
, stdenv
, fetchFromGitHub
, nodejs_20
, npmHooks
}:

stdenv.mkDerivation rec {
  pname = "qwen-code";
  version = "0.0.1-alpha.8";

  src = fetchFromGitHub {
    owner = "QwenLM";
    repo = "qwen-code";
    rev = "bd0d3479c15aaed9c3d0b36e7a0e90194c5b076d";
    hash = "sha256-3hQGN9R9h1xTu0OAwGecmOxXvdNdU78dh7oOfUPNkkA=";
  };

  nativeBuildInputs = [ nodejs_20 ];

  buildPhase = ''
    # Check what's in the source
    echo "=== Source contents ==="
    ls -la
    
    echo "=== Package.json ==="
    cat package.json

    # Set up npm environment
    export HOME=$TMPDIR
    export npm_config_cache=$TMPDIR/.npm
    export npm_config_offline=false
    
    # Install all dependencies (not just production) as this is a build step
    echo "=== Installing dependencies ==="
    npm install --no-audit --no-fund --legacy-peer-deps --timeout 300000
    
    echo "=== Running build ==="
    npm run build
    
    echo "=== Contents after build ==="
    ls -la
    
    # Check if bundle directory was created
    if [ -d bundle ]; then
      echo "=== Bundle contents ==="
      ls -la bundle/
    fi
  '';

  installPhase = ''
    # Create output directories
    mkdir -p $out/lib/node_modules/qwen-code
    mkdir -p $out/bin
    
    # Copy the application
    cp -r . $out/lib/node_modules/qwen-code/
    
    # The main entry point is bundle/gemini.js according to package.json
    if [ -f bundle/gemini.js ]; then
      ENTRY_POINT="bundle/gemini.js"
    elif [ -f bin/qwen.js ]; then
      ENTRY_POINT="bin/qwen.js"
    elif [ -f dist/bin/qwen.js ]; then
      ENTRY_POINT="dist/bin/qwen.js"
    else
      echo "Error: Could not find main entry point"
      ls -la bundle/ || echo "No bundle directory"
      exit 1
    fi
    
    echo "Using entry point: $ENTRY_POINT"
    
    # Create wrapper script
    cat > $out/bin/qwen << EOF
#!/usr/bin/env bash
exec ${nodejs_20}/bin/node $out/lib/node_modules/qwen-code/$ENTRY_POINT "\$@"
EOF
    chmod +x $out/bin/qwen
  '';

  meta = with lib; {
    description = "Command-line AI workflow tool optimized for Qwen3-Coder models";
    homepage = "https://github.com/QwenLM/qwen-code";
    license = licenses.asl20;
    maintainers = [ ];
    platforms = platforms.all;
    mainProgram = "qwen";
  };
}