{ lib
, stdenv
, fetchFromGitHub
, nodejs_24
, makeWrapper
, pm2
,
}:
stdenv.mkDerivation rec {
  pname = "linux-command-mcp";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "xkiranj";
    repo = "linux-command-mcp";
    rev = "main"; # You might want to pin to a specific commit hash for reproducibility
    sha256 = "sha256-hdH537bFbfAk4b9UMYPleIMfqAoZAfMgnj1HaV3kHns=";
    # Nix will provide a hash error on first build, you can copy it from there
  };

  nativeBuildInputs = [
    nodejs_24
    makeWrapper
  ];

  buildInputs = [
    nodejs_24
    pm2
  ];

  buildPhase = ''
    # Build the server
    cd server
    export HOME=$(mktemp -d)
    npm ci
    npm run build
  '';

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/lib/${pname}

    # Copy the built server
    cp -r dist $out/lib/${pname}/
    cp -r node_modules $out/lib/${pname}/
    cp package.json $out/lib/${pname}/
    cp ecosystem.config.cjs $out/lib/${pname}/

    # Create wrapper script
    makeWrapper ${nodejs_24}/bin/node $out/bin/linux-command-mcp \
      --add-flags "$out/lib/${pname}/dist/index.js" \
      --prefix PATH : ${lib.makeBinPath [pm2]}

    # Create PM2 start script
    cat > $out/bin/linux-command-mcp-pm2 << EOF
    #!/bin/sh
    pm2 start $out/lib/${pname}/dist/index.js --name linux-command-mcp-server
    EOF
    chmod +x $out/bin/linux-command-mcp-pm2
  '';

  postFixup = ''
    # Make sure the main script is executable
    chmod +x $out/lib/${pname}/dist/index.js
  '';

  meta = with lib; {
    description = "Linux Command MCP (Model Context Protocol) for secure command execution";
    homepage = "https://github.com/xkiranj/linux-command-mcp";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
