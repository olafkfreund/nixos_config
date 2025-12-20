# LinkedIn MCP Server Package
# Model Context Protocol server for LinkedIn data access
# Repository: https://github.com/stickerdaniel/linkedin-mcp-server
# Follows docs/NIXOS-ANTI-PATTERNS.md and docs/PATTERNS.md
{ writeShellScriptBin
, docker
, ...
}:

writeShellScriptBin "linkedin-mcp" ''
  #!/bin/sh
  # Wrapper script for LinkedIn MCP server (Docker method)
  # Uses official Docker image: stickerdaniel/linkedin-mcp-server:latest

  set -euo pipefail

  # Check if LINKEDIN_COOKIE_FILE environment variable is set
  if [ -z "''${LINKEDIN_COOKIE_FILE:-}" ]; then
    echo "Error: LINKEDIN_COOKIE_FILE environment variable not set" >&2
    echo "This should point to the li_at cookie file" >&2
    echo "Example: export LINKEDIN_COOKIE_FILE=/run/agenix/api-linkedin-cookie" >&2
    exit 1
  fi

  # Verify cookie file exists and is readable
  if [ ! -f "$LINKEDIN_COOKIE_FILE" ]; then
    echo "Error: Cookie file not found: $LINKEDIN_COOKIE_FILE" >&2
    exit 1
  fi

  if [ ! -r "$LINKEDIN_COOKIE_FILE" ]; then
    echo "Error: Cookie file not readable: $LINKEDIN_COOKIE_FILE" >&2
    exit 1
  fi

  # Read the cookie value (runtime loading - NEVER evaluation time!)
  LINKEDIN_COOKIE=$(cat "$LINKEDIN_COOKIE_FILE")

  if [ -z "$LINKEDIN_COOKIE" ]; then
    echo "Error: Cookie file is empty: $LINKEDIN_COOKIE_FILE" >&2
    exit 1
  fi

  # Run LinkedIn MCP server via Docker with cookie as environment variable
  # Docker container runs isolated with minimal permissions
  exec ${docker}/bin/docker run \
    --rm \
    -i \
    --read-only \
    --security-opt=no-new-privileges \
    --cap-drop=ALL \
    -e LINKEDIN_COOKIE="$LINKEDIN_COOKIE" \
    stickerdaniel/linkedin-mcp-server:latest \
    "$@"
''
