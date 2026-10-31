# Atlassian MCP Server Package
# Model Context Protocol server for Jira and Confluence
# Repository: https://github.com/sooperset/mcp-atlassian
# Follows docs/NIXOS-ANTI-PATTERNS.md and docs/PATTERNS.md
{ writeShellScriptBin
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

  # load_secret FILE_VAR OUT_VAR LABEL MODE_LABEL EXAMPLE_PATH
  # Reads the secret file named by $FILE_VAR at runtime (never at evaluation time).
  load_secret() {
    local file_var="$1" out_var="$2" label="$3" mode_label="$4" example="$5"
    local file="''${!file_var:-}"

    if [ -z "$file" ]; then
      echo "Error: $file_var environment variable not set ($mode_label mode)" >&2
      echo "This should point to the $label file" >&2
      echo "Example: export $file_var=$example" >&2
      exit 1
    fi
    if [ ! -f "$file" ]; then
      echo "Error: $label file not found: $file" >&2
      exit 1
    fi
    if [ ! -r "$file" ]; then
      echo "Error: $label file not readable: $file" >&2
      exit 1
    fi

    local value
    value=$(cat "$file")
    if [ -z "$value" ]; then
      echo "Error: $label file is empty: $file" >&2
      exit 1
    fi
    export "$out_var=$value"
  }

  require_var() {
    if [ -z "''${!1:-}" ]; then
      echo "Error: $1 environment variable not set (cloud mode)" >&2
      echo "Set $1 to your Atlassian account email" >&2
      exit 1
    fi
  }

  if [ "$MODE" = "cloud" ]; then
    if [ -n "''${JIRA_URL:-}" ]; then
      require_var JIRA_USERNAME
      load_secret JIRA_TOKEN_FILE JIRA_API_TOKEN "Jira API token" cloud /run/agenix/api-jira-token
    fi
    if [ -n "''${CONFLUENCE_URL:-}" ]; then
      require_var CONFLUENCE_USERNAME
      load_secret CONFLUENCE_TOKEN_FILE CONFLUENCE_API_TOKEN "Confluence API token" cloud /run/agenix/api-confluence-token
    fi
  elif [ "$MODE" = "self-hosted" ]; then
    if [ -n "''${JIRA_URL:-}" ]; then
      load_secret JIRA_PAT_FILE JIRA_PAT "Jira PAT" self-hosted /run/agenix/api-jira-pat
    fi
    if [ -n "''${CONFLUENCE_URL:-}" ]; then
      load_secret CONFLUENCE_PAT_FILE CONFLUENCE_PAT "Confluence PAT" self-hosted /run/agenix/api-confluence-pat
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
