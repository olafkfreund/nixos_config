# Atlassian MCP Server Package
# Model Context Protocol server for Jira and Confluence
# Repository: https://github.com/sooperset/mcp-atlassian
# Follows docs/NIXOS-ANTI-PATTERNS.md and docs/PATTERNS.md
{ lib
, writeShellScriptBin
, python3
, uv
, ...
}:

writeShellScriptBin "atlassian-mcp" ''
  #!/bin/sh
  # Wrapper script for Atlassian MCP server (uvx method)
  # Uses uvx for direct Python package execution
  # Supports both Jira and Confluence with cloud/self-hosted modes

  set -euo pipefail

  # Determine mode from environment variable
  MODE="''${ATLASSIAN_MODE:-cloud}"

  # Cloud mode: requires username + API token
  # Self-hosted mode: requires Personal Access Token (PAT)

  if [ "$MODE" = "cloud" ]; then
    # Cloud authentication: username + API token

    # Check if JIRA credentials are configured
    if [ -n "''${JIRA_URL:-}" ]; then
      if [ -z "''${JIRA_USERNAME:-}" ]; then
        echo "Error: JIRA_USERNAME environment variable not set (cloud mode)" >&2
        echo "Set JIRA_USERNAME to your Atlassian account email" >&2
        exit 1
      fi

      if [ -z "''${JIRA_TOKEN_FILE:-}" ]; then
        echo "Error: JIRA_TOKEN_FILE environment variable not set (cloud mode)" >&2
        echo "This should point to the Jira API token file" >&2
        echo "Example: export JIRA_TOKEN_FILE=/run/agenix/api-jira-token" >&2
        exit 1
      fi

      # Verify Jira token file exists and is readable
      if [ ! -f "$JIRA_TOKEN_FILE" ]; then
        echo "Error: Jira token file not found: $JIRA_TOKEN_FILE" >&2
        exit 1
      fi

      if [ ! -r "$JIRA_TOKEN_FILE" ]; then
        echo "Error: Jira token file not readable: $JIRA_TOKEN_FILE" >&2
        exit 1
      fi

      # Read the Jira token (runtime loading - NEVER evaluation time!)
      JIRA_API_TOKEN=$(cat "$JIRA_TOKEN_FILE")

      if [ -z "$JIRA_API_TOKEN" ]; then
        echo "Error: Jira token file is empty: $JIRA_TOKEN_FILE" >&2
        exit 1
      fi

      export JIRA_API_TOKEN
    fi

    # Check if Confluence credentials are configured
    if [ -n "''${CONFLUENCE_URL:-}" ]; then
      if [ -z "''${CONFLUENCE_USERNAME:-}" ]; then
        echo "Error: CONFLUENCE_USERNAME environment variable not set (cloud mode)" >&2
        echo "Set CONFLUENCE_USERNAME to your Atlassian account email" >&2
        exit 1
      fi

      if [ -z "''${CONFLUENCE_TOKEN_FILE:-}" ]; then
        echo "Error: CONFLUENCE_TOKEN_FILE environment variable not set (cloud mode)" >&2
        echo "This should point to the Confluence API token file" >&2
        echo "Example: export CONFLUENCE_TOKEN_FILE=/run/agenix/api-confluence-token" >&2
        exit 1
      fi

      # Verify Confluence token file exists and is readable
      if [ ! -f "$CONFLUENCE_TOKEN_FILE" ]; then
        echo "Error: Confluence token file not found: $CONFLUENCE_TOKEN_FILE" >&2
        exit 1
      fi

      if [ ! -r "$CONFLUENCE_TOKEN_FILE" ]; then
        echo "Error: Confluence token file not readable: $CONFLUENCE_TOKEN_FILE" >&2
        exit 1
      fi

      # Read the Confluence token (runtime loading - NEVER evaluation time!)
      CONFLUENCE_API_TOKEN=$(cat "$CONFLUENCE_TOKEN_FILE")

      if [ -z "$CONFLUENCE_API_TOKEN" ]; then
        echo "Error: Confluence token file is empty: $CONFLUENCE_TOKEN_FILE" >&2
        exit 1
      fi

      export CONFLUENCE_API_TOKEN
    fi

  elif [ "$MODE" = "self-hosted" ]; then
    # Self-hosted authentication: Personal Access Token (PAT)

    # Check if JIRA PAT is configured
    if [ -n "''${JIRA_URL:-}" ]; then
      if [ -z "''${JIRA_PAT_FILE:-}" ]; then
        echo "Error: JIRA_PAT_FILE environment variable not set (self-hosted mode)" >&2
        echo "This should point to the Jira Personal Access Token file" >&2
        echo "Example: export JIRA_PAT_FILE=/run/agenix/api-jira-pat" >&2
        exit 1
      fi

      # Verify Jira PAT file exists and is readable
      if [ ! -f "$JIRA_PAT_FILE" ]; then
        echo "Error: Jira PAT file not found: $JIRA_PAT_FILE" >&2
        exit 1
      fi

      if [ ! -r "$JIRA_PAT_FILE" ]; then
        echo "Error: Jira PAT file not readable: $JIRA_PAT_FILE" >&2
        exit 1
      fi

      # Read the Jira PAT (runtime loading - NEVER evaluation time!)
      JIRA_PAT=$(cat "$JIRA_PAT_FILE")

      if [ -z "$JIRA_PAT" ]; then
        echo "Error: Jira PAT file is empty: $JIRA_PAT_FILE" >&2
        exit 1
      fi

      export JIRA_PAT
    fi

    # Check if Confluence PAT is configured
    if [ -n "''${CONFLUENCE_URL:-}" ]; then
      if [ -z "''${CONFLUENCE_PAT_FILE:-}" ]; then
        echo "Error: CONFLUENCE_PAT_FILE environment variable not set (self-hosted mode)" >&2
        echo "This should point to the Confluence Personal Access Token file" >&2
        echo "Example: export CONFLUENCE_PAT_FILE=/run/agenix/api-confluence-pat" >&2
        exit 1
      fi

      # Verify Confluence PAT file exists and is readable
      if [ ! -f "$CONFLUENCE_PAT_FILE" ]; then
        echo "Error: Confluence PAT file not found: $CONFLUENCE_PAT_FILE" >&2
        exit 1
      fi

      if [ ! -r "$CONFLUENCE_PAT_FILE" ]; then
        echo "Error: Confluence PAT file not readable: $CONFLUENCE_PAT_FILE" >&2
        exit 1
      fi

      # Read the Confluence PAT (runtime loading - NEVER evaluation time!)
      CONFLUENCE_PAT=$(cat "$CONFLUENCE_PAT_FILE")

      if [ -z "$CONFLUENCE_PAT" ]; then
        echo "Error: Confluence PAT file is empty: $CONFLUENCE_PAT_FILE" >&2
        exit 1
      fi

      export CONFLUENCE_PAT
    fi

  else
    echo "Error: Invalid ATLASSIAN_MODE: $MODE" >&2
    echo "Valid modes: cloud, self-hosted" >&2
    exit 1
  fi

  # Verify at least one product is configured
  if [ -z "''${JIRA_URL:-}" ] && [ -z "''${CONFLUENCE_URL:-}" ]; then
    echo "Error: Neither JIRA_URL nor CONFLUENCE_URL is set" >&2
    echo "At least one Atlassian product must be configured" >&2
    exit 1
  fi

  # Run Atlassian MCP server via uvx
  # uvx automatically handles Python environment and dependencies
  exec ${uv}/bin/uvx mcp-atlassian "$@"
''
