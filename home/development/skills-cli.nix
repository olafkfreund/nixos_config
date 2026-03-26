# Skills CLI - Agent skills package manager
# Provides the `skills` command for managing AI agent skills (SKILL.md format)
# Source: https://github.com/vercel-labs/skills
{ pkgs, ... }:
let
  # Wrapper script that provides the `skills` command via npx
  skills-cli = pkgs.writeShellScriptBin "skills" ''
    set -euo pipefail

    if ! command -v npx &>/dev/null; then
      echo "Error: npx not found. Ensure nodejs is installed." >&2
      exit 1
    fi

    exec npx --yes skills "$@"
  '';
in
{
  home.packages = [
    skills-cli
  ];
}
