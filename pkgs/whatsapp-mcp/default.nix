# WhatsApp MCP Server - Complete Package
# Provides AI-assisted WhatsApp interaction through Model Context Protocol
# Follows docs/PATTERNS.md and docs/NIXOS-ANTI-PATTERNS.md

{ lib
, stdenv
, buildGoModule
, python3
, fetchFromGitHub
, makeWrapper
, sqlite
, ffmpeg
}:

let
  version = "unstable-2025-01-09";

  src = fetchFromGitHub {
    owner = "lharries";
    repo = "whatsapp-mcp";
    rev = "main";
    hash = "sha256-z05PFRmODaIEfcFwNt7UO4crkgHGeI3fN95AXlYNeeY=";
  };

  # Go bridge component
  whatsappBridge = buildGoModule {
    pname = "whatsapp-bridge";
    inherit version src;

    sourceRoot = "${src.name}/whatsapp-bridge";

    vendorHash = "sha256-8yTDqljzX2N69Q+GHA3BI8FXpR0nhR3N6ke1UFYPp6g=";

    # Build-time dependencies
    nativeBuildInputs = [ makeWrapper ];

    # Runtime dependencies
    buildInputs = [ sqlite ];

    # Strict dependency separation (PATTERNS.md requirement)
    strictDeps = true;

    # Go build configuration
    env = {
      CGO_ENABLED = "1"; # Required for SQLite
    };

    buildPhase = ''
      runHook preBuild
      go build -v -o whatsapp-bridge .
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      install -Dm755 whatsapp-bridge $out/bin/whatsapp-bridge

      runHook postInstall
    '';

    meta = with lib; {
      description = "WhatsApp Web API bridge for MCP servers";
      longDescription = ''
        Go application that connects to WhatsApp Web API,
        handles QR code authentication, and provides message
        operations through a SQLite database backend.
      '';
      homepage = "https://github.com/lharries/whatsapp-mcp";
      license = licenses.mit;
      maintainers = [ ];
      platforms = platforms.linux;
      mainProgram = "whatsapp-bridge";
    };
  };

  # Python MCP server component
  whatsappMcpServer = stdenv.mkDerivation {
    pname = "whatsapp-mcp-server";
    inherit version src;

    sourceRoot = "${src.name}/whatsapp-mcp-server";

    nativeBuildInputs = [ makeWrapper python3 ];

    buildInputs = [ python3 ];

    # Install Python files and create wrapper
    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/whatsapp-mcp-server
      cp -r *.py $out/lib/whatsapp-mcp-server/

      mkdir -p $out/bin
      makeWrapper ${python3}/bin/python3 $out/bin/whatsapp-mcp-server \
        --add-flags "$out/lib/whatsapp-mcp-server/main.py" \
        --prefix PYTHONPATH : "$out/lib/whatsapp-mcp-server:${python3.pkgs.httpx}/${python3.sitePackages}:${python3.pkgs.mcp}/${python3.sitePackages}:${python3.pkgs.requests}/${python3.sitePackages}"

      runHook postInstall
    '';

    meta = with lib; {
      description = "MCP server for WhatsApp messaging integration";
      longDescription = ''
        Python server implementing the Model Context Protocol
        for AI-assisted WhatsApp interactions. Translates natural
        language commands into WhatsApp operations.
      '';
      homepage = "https://github.com/lharries/whatsapp-mcp";
      license = licenses.mit;
      maintainers = [ ];
      platforms = platforms.linux;
      mainProgram = "whatsapp-mcp-server";
    };
  };

in
# Combined package with both components
stdenv.mkDerivation {
  pname = "whatsapp-mcp";
  inherit version;

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [ whatsappBridge whatsappMcpServer python3 ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    # Install Go bridge
    ln -s ${whatsappBridge}/bin/whatsapp-bridge $out/bin/whatsapp-bridge

    # Install Python MCP server with wrapper
    makeWrapper ${whatsappMcpServer}/bin/whatsapp-mcp-server $out/bin/whatsapp-mcp-server \
      --prefix PATH : ${lib.makeBinPath [ whatsappBridge ]} \
      --set WHATSAPP_BRIDGE_BIN ${whatsappBridge}/bin/whatsapp-bridge

    # Optional: FFmpeg for voice message conversion
    ${lib.optionalString (ffmpeg != null) ''
      makeWrapper $out/bin/whatsapp-mcp-server $out/bin/whatsapp-mcp-server-ffmpeg \
        --prefix PATH : ${lib.makeBinPath [ whatsappBridge ffmpeg ]} \
        --set WHATSAPP_BRIDGE_BIN ${whatsappBridge}/bin/whatsapp-bridge \
        --set FFMPEG_BIN ${ffmpeg}/bin/ffmpeg
    ''}

    runHook postInstall
  '';

  passthru = {
    inherit whatsappBridge whatsappMcpServer;
  };

  meta = with lib; {
    description = "WhatsApp MCP server for AI-assisted messaging";
    longDescription = ''
      Complete WhatsApp MCP integration consisting of:
      - Go bridge connecting to WhatsApp Web API
      - Python MCP server for AI agent interactions
      - SQLite database for message history
      - Optional FFmpeg support for voice messages
    '';
    homepage = "https://github.com/lharries/whatsapp-mcp";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
