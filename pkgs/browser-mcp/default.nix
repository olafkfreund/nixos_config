# BrowserMCP - Model Context Protocol server for browser automation
# Enables AI agents to control the browser for web automation tasks
# Documentation: https://docs.browsermcp.io/setup-server
{ nodejs
, writeShellScriptBin
, ...
}:

writeShellScriptBin "browser-mcp" ''
  # BrowserMCP MCP Server
  # Uses npx to run a pinned version of @browsermcp/mcp
  exec ${nodejs}/bin/npx --yes @browsermcp/mcp@2.3.0 "$@"
''
