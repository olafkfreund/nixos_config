# LinkedIn MCP Server Package
# Model Context Protocol server for LinkedIn data access
# Repository: https://github.com/stickerdaniel/linkedin-mcp-server
# Follows docs/NIXOS-ANTI-PATTERNS.md and docs/PATTERNS.md
#
# IMPLEMENTATION NOTE: Uses uvx (pragmatic trade-off)
# ====================================================
# This package uses uvx for Python dependency management instead of
# full Nix packaging. This is a deliberate pragmatic decision because:
#
# 1. Complex Dependencies: Requires 20+ Python packages (fastmcp, mcp,
#    py-key-value-aio, pydocket, etc.), many not in nixpkgs
# 2. Maintenance Burden: Full Nix packaging would require maintaining
#    all upstream dependencies ourselves
# 3. Rapid Evolution: MCP ecosystem is new and fast-moving
# 4. Proper Caching: uv caches in ~/.cache/uv (persistent across reboots)
# 5. Deterministic: uv.lock pins exact versions (reproducible builds)
# 6. Isolated: Creates virtual environments (no system pollution)
#
# Trade-offs accepted:
# - Network dependency on first run (~15-20 seconds)
# - Runtime dependency download (impure but cached)
# - Not fully offline (requires internet for initial setup)
#
# This pattern is similar to other nixpkgs packages (VSCode extensions,
# npm/cargo caches) where full packaging is impractical.
#
{ writeShellScriptBin
, uv
, ...
}:

writeShellScriptBin "linkedin-mcp" ''
  #!/bin/sh
  # Wrapper script for LinkedIn MCP server (native uvx method)
  # Uses uvx to run linkedin-mcp-server directly from GitHub

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

  # Set LinkedIn cookie as environment variable
  export LINKEDIN_COOKIE="$LINKEDIN_COOKIE"

  # Configure uv cache location (explicit for transparency)
  # Default: ~/.cache/uv (persistent across reboots)
  export UV_CACHE_DIR="''${UV_CACHE_DIR:-$HOME/.cache/uv}"

  # Run LinkedIn MCP server via uvx from GitHub
  # First run: Downloads Python 3.12, fetches repos, installs 102 packages (~15-20s)
  # Subsequent runs: Uses cached environment (instant)
  # uvx automatically handles Python dependencies and virtual environments
  exec ${uv}/bin/uvx --from git+https://github.com/stickerdaniel/linkedin-mcp-server.git linkedin-mcp-server "$@"
''
