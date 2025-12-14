# Obsidian MCP Server Package (REST API)
# Uses mcp-obsidian from PyPI via uvx for full CRUD functionality
# Requires Obsidian Local REST API plugin to be installed
{ writeShellScriptBin
, uv
, ...
}:

writeShellScriptBin "obsidian-mcp-rest" ''
  #!/bin/sh
  # Wrapper script for mcp-obsidian (REST API implementation)
  # Uses uvx to run the latest mcp-obsidian from PyPI
  # Provides full CRUD operations via Obsidian Local REST API plugin

  # Security: Runtime secret loading following docs/NIXOS-ANTI-PATTERNS.md
  if [ -z "$OBSIDIAN_API_KEY_FILE" ] && [ -z "$OBSIDIAN_API_KEY" ]; then
    echo "Error: OBSIDIAN_API_KEY_FILE or OBSIDIAN_API_KEY environment variable required"
    echo ""
    echo "Usage: obsidian-mcp-rest"
    echo ""
    echo "Required environment variables:"
    echo "  OBSIDIAN_API_KEY_FILE - Path to file containing API key (preferred, runtime loading)"
    echo "  OBSIDIAN_API_KEY - API key directly (fallback, less secure)"
    echo ""
    echo "Optional environment variables:"
    echo "  OBSIDIAN_HOST - API host (default: localhost)"
    echo "  OBSIDIAN_PORT - API port (default: 27123)"
    echo "  VERIFY_SSL - Verify SSL certificates (default: true)"
    echo "  REQUEST_TIMEOUT - Request timeout in ms (default: 30000)"
    exit 1
  fi

  # Load API key from file if specified (runtime loading)
  if [ -n "$OBSIDIAN_API_KEY_FILE" ]; then
    if [ ! -f "$OBSIDIAN_API_KEY_FILE" ]; then
      echo "Error: API key file not found: $OBSIDIAN_API_KEY_FILE"
      exit 1
    fi
    export OBSIDIAN_API_KEY=$(cat "$OBSIDIAN_API_KEY_FILE")
  fi

  # Set defaults for optional parameters
  export OBSIDIAN_HOST="''${OBSIDIAN_HOST:-localhost}"
  export OBSIDIAN_PORT="''${OBSIDIAN_PORT:-27123}"
  export VERIFY_SSL="''${VERIFY_SSL:-true}"
  export REQUEST_TIMEOUT="''${REQUEST_TIMEOUT:-30000}"

  # Run mcp-obsidian via uvx (uses pip package)
  # uvx caches the package after first use for performance
  exec ${uv}/bin/uvx mcp-obsidian
''
