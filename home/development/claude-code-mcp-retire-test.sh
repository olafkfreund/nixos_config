#!/usr/bin/env bash
set -euo pipefail

desired=$1
activation=$2
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export HOME="$fixture"
export DRY_RUN_CMD=
mkdir -p "$HOME/.claude"

jq --slurpfile d "$desired" -n '
  $d[0] | .mcpServers += {
    atlassian: {command: "retired"},
    unrelated: {command: "preserve", args: ["--flag"]}
  }
' >"$HOME/.claude.json"
jq -n '{mcpServers: {
  atlassian: {command: "retired"},
  unrelated: {command: "preserve", args: ["--flag"]}
}, otherSetting: {nested: [1, 2]}}' >"$HOME/.claude/settings.local.json"

for file in "$HOME/.claude.json" "$HOME/.claude/settings.local.json"; do
  jq -S 'del(.mcpServers.atlassian)' "$file" >"$file.expected"
done

bash "$activation" >/dev/null

for file in "$HOME/.claude.json" "$HOME/.claude/settings.local.json"; do
  jq -e '.mcpServers | has("atlassian") | not' "$file" >/dev/null
  jq -S . "$file" >"$file.actual"
  cmp -s "$file.expected" "$file.actual"
done

# The retired key alone must trigger the shared-file reconcile.
test -f "$HOME/.claude.json.bak"

before=$(sha256sum "$HOME/.claude.json" "$HOME/.claude/settings.local.json")
bash "$activation" >/dev/null
after=$(sha256sum "$HOME/.claude.json" "$HOME/.claude/settings.local.json")
test "$before" = "$after"

# Dry run: nothing changes, and no temp copy (it holds credentials) is left behind.
rm -f "$HOME"/.claude.json.* "$HOME"/.claude/settings.local.json.*
jq '.mcpServers += {atlassian: {command: "retired"}}' "$HOME/.claude.json" >"$fixture/c" && mv "$fixture/c" "$HOME/.claude.json"
jq '.mcpServers += {atlassian: {command: "retired"}}' "$HOME/.claude/settings.local.json" >"$fixture/s" \
  && mv "$fixture/s" "$HOME/.claude/settings.local.json"
before=$(sha256sum "$HOME/.claude.json" "$HOME/.claude/settings.local.json")
DRY_RUN_CMD="echo" bash "$activation" >/dev/null
after=$(sha256sum "$HOME/.claude.json" "$HOME/.claude/settings.local.json")
test "$before" = "$after"
leftover=$(find "$HOME" -maxdepth 2 \( -name '.claude.json.*' -o -name '.settings.local.json.*' \) -print -quit)
test -z "$leftover"
