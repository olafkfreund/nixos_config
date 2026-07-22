# Ollama code-delegation MCP server.
#
# A stdio MCP server that lets Claude Code hand isolated coding tasks to a
# local Ollama coder model (qwen2.5-coder on p620/p510) and review the output.
# Stateless — spawned per session by Claude Code, no daemon or port.
#
# The server is ~40 lines of Python against nixpkgs' python3Packages.mcp
# (FastMCP); it forwards to Ollama's OpenAI-compatible /v1 endpoint.
{ python3, writeShellApplication }:
let
  pyEnv = python3.withPackages (ps: [ ps.mcp ]);
in
writeShellApplication {
  name = "ollama-mcp";
  runtimeInputs = [ pyEnv ];
  text = ''
    exec python3 ${./server.py} "$@"
  '';
}
