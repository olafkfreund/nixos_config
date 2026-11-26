#!/usr/bin/env bash
# Bash|Grep nudge toward graphify, skipped for searches aimed at .nix, docs or
# ~/.claude: graphify indexes none of them, so the nudge was only noise (#3244).
command -v graphify >/dev/null 2>&1 || exit 0
payload=$(cat)
if command -v jq >/dev/null 2>&1 && jq -e '
  .tool_input | [.glob, .type, .path, .command] | map(. // "") | join(" ")
  | test("\\.nix\\b|\\.md\\b|--type[= ]nix|\\.claude/|/nix/store")' <<<"$payload" >/dev/null 2>&1; then
  exit 0
fi
exec graphify hook-guard search <<<"$payload"
