{ lib
, stdenv
, fetchFromGitHub
, nodejs_20
, npmHooks
, makeWrapper
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

  nativeBuildInputs = [ nodejs_20 makeWrapper ];

  # Use the global npm install approach
  buildPhase = ''
    export HOME=$TMPDIR
    export npm_config_cache=$TMPDIR/.npm
    export npm_config_fund=false
    export npm_config_audit=false
    export npm_config_progress=false
    
    echo "=== Installing qwen-code globally ==="
    # Install the package globally using npm, which handles the workspace resolution
    npm install -g @qwen-code/qwen-code --prefix $TMPDIR/npm-global --registry https://registry.npmjs.org/
    
    echo "=== Contents after global install ==="
    find $TMPDIR/npm-global -type f -name "*.js" | head -10
  '';

  installPhase = ''
    mkdir -p $out/bin $out/lib/node_modules
    
    # Copy the globally installed package
    if [ -d "$TMPDIR/npm-global/lib/node_modules/@qwen-code" ]; then
      cp -r "$TMPDIR/npm-global/lib/node_modules/@qwen-code" "$out/lib/node_modules/"
      
      # Find the main executable
      MAIN_JS=$(find "$out/lib/node_modules/@qwen-code" -name "*.js" -executable -o -name "index.js" -o -name "gemini.js" | head -1)
      
      if [ -n "$MAIN_JS" ]; then
        makeWrapper ${nodejs_20}/bin/node $out/bin/qwen \
          --add-flags "$MAIN_JS"
      else
        echo "Could not find main executable"
        exit 1
      fi
      
    elif [ -d "$TMPDIR/npm-global/bin" ]; then
      # Fallback: copy bin directory
      cp -r "$TMPDIR/npm-global/bin/"* "$out/bin/" || true
      chmod +x "$out/bin/"* || true
      
    else
      echo "Global npm install failed or package not found"
      ls -la "$TMPDIR/npm-global" || true
      exit 1
    fi
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
    maintainers = [ ];
    platforms = platforms.all;
    mainProgram = "qwen";
  };
}