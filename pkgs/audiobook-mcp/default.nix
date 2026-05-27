# audiobook-mcp — local MCP server for audiobook acquisition + library.
#
# Authored in-repo (audiobook_mcp.py). Exposes tools over the two acquisition
# sources (AudioBookBay via the audiobookbay-automated app, NZBGeek/Usenet via
# Prowlarr → SABnzbd) plus Audiobookshelf library lookups. Stdio MCP server
# (FastMCP); wrapped into an SSE daemon by modules/services/audiobook-mcp.nix.
#
# Packaged as a python env + wrapper (single module, no upstream pyproject).
{ lib
, stdenvNoCC
, makeWrapper
, python3
}:
let
  pythonEnv = python3.withPackages (ps: with ps; [
    mcp
    httpx
    beautifulsoup4
  ]);
in
stdenvNoCC.mkDerivation {
  pname = "audiobook-mcp";
  version = "0.1.0";

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm644 ${./audiobook_mcp.py} $out/share/audiobook-mcp/audiobook_mcp.py
    makeWrapper ${pythonEnv}/bin/python $out/bin/audiobook-mcp \
      --add-flags "$out/share/audiobook-mcp/audiobook_mcp.py"

    runHook postInstall
  '';

  meta = {
    description = "MCP server for audiobook acquisition (AudioBookBay + NZBGeek) and Audiobookshelf";
    homepage = "https://github.com/olafkfreund/nixos_config";
    license = lib.licenses.mit;
    mainProgram = "audiobook-mcp";
    platforms = lib.platforms.linux;
  };
}
