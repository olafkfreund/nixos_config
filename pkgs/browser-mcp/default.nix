# BrowserMCP - Model Context Protocol server for browser automation
# Enables AI agents to control the browser for web automation tasks
# Documentation: https://docs.browsermcp.io/setup-server
{ pkgs, ... }:

pkgs.writeShellScriptBin "browser-mcp" ''
  # BrowserMCP MCP Server
  # Uses npx to run the latest version of @browsermcp/mcp
  exec ${pkgs.nodejs_22}/bin/npx --yes @browsermcp/mcp@latest "$@"
''
