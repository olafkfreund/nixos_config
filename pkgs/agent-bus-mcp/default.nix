# agent-bus-mcp — a shared room for coding agents, exposed as MCP tools.
#
# Authored in-repo (agent_bus_mcp.py). Four tools over a Matrix room: post,
# read_new, list_rooms, search. Stdio MCP server (FastMCP), wrapped into an SSE
# daemon by modules/services/agent-bus-mcp.nix the same way plex-mcp,
# arr-suite-mcp and audiobook-mcp are.
#
# Packaged as a python env + wrapper, matching pkgs/audiobook-mcp: a single
# vendored module needs no pyproject, and python3Packages.mcp carries FastMCP.
#
# httpx rather than matrix-nio: this speaks four REST endpoints and holds no
# sync loop, so a client library would be more surface than it saves. The rooms
# are deliberately unencrypted — E2EE with bot accounts is the single largest
# complexity trap in Matrix and buys nothing on a server that does not federate.
{ lib
, stdenvNoCC
, makeWrapper
, python3
}:
let
  pythonEnv = python3.withPackages (ps: with ps; [
    mcp
    httpx
  ]);
in
stdenvNoCC.mkDerivation {
  pname = "agent-bus-mcp";
  version = "0.1.0";

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm644 ${./agent_bus_mcp.py} $out/share/agent-bus-mcp/agent_bus_mcp.py
    makeWrapper ${pythonEnv}/bin/python $out/bin/agent-bus-mcp \
      --add-flags "$out/share/agent-bus-mcp/agent_bus_mcp.py"

    runHook postInstall
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    AGENT_BUS_MODULE=${./agent_bus_mcp.py} \
      ${pythonEnv}/bin/python ${./test_agent_bus_mcp.py}
    runHook postCheck
  '';

  meta = {
    description = "MCP server giving coding agents a shared Matrix room";
    longDescription = ''
      Agents post what they learned and read what they missed, as MCP tools
      rather than by driving a terminal UI. Cursors are stored per agent and
      room, so `read_new` returns exactly what has happened since that agent
      last looked — which is the question an agent actually has, given it runs
      in turns rather than holding a connection open.

      Backed by a Matrix homeserver, so the same rooms are readable by humans
      in any Matrix client.
    '';
    homepage = "https://github.com/olafkfreund/nixos_config";
    license = lib.licenses.mit;
    mainProgram = "agent-bus-mcp";
    platforms = lib.platforms.linux;
  };
}
