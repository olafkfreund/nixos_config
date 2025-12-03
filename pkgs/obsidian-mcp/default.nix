# Obsidian MCP Server Package
# Lightweight Model Context Protocol server for Obsidian vault access
# Uses @mauricio.wolff/mcp-obsidian - zero dependencies, no plugins required
{ lib
, writeShellScriptBin
, nodejs
, ...
}:

writeShellScriptBin "obsidian-mcp" ''
  #!/bin/sh
  # Wrapper script for @mauricio.wolff/mcp-obsidian
  # Ensures npx is available and runs the latest version

  if [ $# -eq 0 ]; then
    echo "Usage: obsidian-mcp <vault-path>"
    echo ""
    echo "Example: obsidian-mcp ~/Documents/ObsidianVault"
    echo ""
    echo "Environment variables:"
    echo "  OBSIDIAN_VAULT_PATH - Default vault path (optional)"
    exit 1
  fi

  VAULT_PATH="''${1:-$OBSIDIAN_VAULT_PATH}"

  if [ -z "$VAULT_PATH" ]; then
    echo "Error: No vault path specified"
    exit 1
  fi

  if [ ! -d "$VAULT_PATH" ]; then
    echo "Error: Vault path does not exist: $VAULT_PATH"
    exit 1
  fi

  # npx is included with nodejs package
  exec ${nodejs}/bin/npx @mauricio.wolff/mcp-obsidian@latest "$VAULT_PATH"
''
