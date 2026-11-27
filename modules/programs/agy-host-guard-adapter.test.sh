#!/usr/bin/env bash
# Run with bash. Requires jq on PATH.
set -eu

here=$(dirname "$0")
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export GUARD_CWD="$tmp/cwd.json"

printf '%s\n' '#!/usr/bin/env bash' 'echo ignored stdout' 'exit 0' >"$tmp/allow"
printf '%s\n' '#!/usr/bin/env bash' 'echo crashed >&2' 'exit 1' >"$tmp/crash"
cat >"$tmp/check" <<'EOF'
#!/usr/bin/env bash
payload=$(cat)
jq -c 'if has("cwd") then .cwd else "omitted" end' <<<"$payload" >"$GUARD_CWD"
if jq -e '.tool_input.command == "danger"' <<<"$payload" >/dev/null; then
  echo 'blocked danger' >&2
  exit 2
fi
EOF
chmod +x "$tmp/allow" "$tmp/crash" "$tmp/check"
sed -e 's#@jq@#jq#g' -e "s#@guards@#$tmp/allow $tmp/check#" "$here/agy-host-guard-adapter.sh" >"$tmp/adapter"
sed -e 's#@jq@#jq#g' -e "s#@guards@#$tmp/allow $tmp/crash#" "$here/agy-host-guard-adapter.sh" >"$tmp/crash-adapter"

t() {
  local payload="$1" decision="$2" reason="${3-}" adapter="${4:-$tmp/adapter}" reply
  if ! reply=$(bash "$adapter" <<<"$payload") \
    || ! jq -es --arg decision "$decision" --arg reason "$reason" '
      . == [if $decision == "allow" then {decision:$decision}
            else {decision:$decision, reason:$reason} end]
    ' <<<"$reply" >/dev/null; then
    printf 'FAIL payload=%s expected=%s reason=%q reply=%s\n' "$payload" "$decision" "$reason" "$reply"
    exit 1
  fi
}

t '{"toolCall":{"name":"run_command","args":{"CommandLine":"echo hi"}}}' allow
t '{"toolCall":{"name":"run_command","args":{"CommandLine":"danger"}}}' deny $'blocked danger\n'
t '{"toolCall":{"name":"run_command","args":{"CommandLine":"echo hi"}}}' deny \
  $'host guard crash failed (exit 1): crashed\n' "$tmp/crash-adapter"
t '{"toolCall":{"name":"view_file","args":{"CommandLine":"danger"}}}' allow
t '{"toolCall":{"name":"write_to_file","args":{"CommandLine":"danger"}}}' allow
t '{"toolCall":{"name":"run_command","args":{"CommandLine":["danger"]}}}' allow
t '{"toolCall":{"name":"run_command","args":{}}}' allow
t '{"toolCall":{"name":"run_command","args":{"commandline":"danger"}}}' deny $'blocked danger\n'
t '{"toolCall":{"name":"run_command","args":{"CommandLine":"echo hi","commandline":"danger"}}}' deny \
  'host guard refuses ambiguous CommandLine'
t '{"toolCall":{"name":"run_command","args":{"CommandLine":{"nested":0},"CommandLine":"danger"}}}' deny \
  'host guard refuses ambiguous CommandLine'
t '{"toolCall":{"name":"run_command","args":{"CommandLine":"echo hi","bypaſsSandbox":true}}}' deny \
  'host guard refuses non-ASCII key names'
t 'not JSON' allow
t '{"toolCall":{"name":"run_command","args":{"CommandLine":"danger"}}} invalid' allow

workspace="$tmp/work space"
mkdir "$workspace"
check_cwd() {
  local args="$1" workspaces="$2" expected="$3"
  rm -f "$GUARD_CWD"
  t "$(jq -cn --argjson args "$args" --argjson workspaces "$workspaces" '
    {toolCall:{name:"run_command",args:({CommandLine:"echo hi"} + $args)},workspacePaths:$workspaces}
  ')" allow
  if ! jq -e --arg expected "$expected" '. == $expected' "$GUARD_CWD" >/dev/null; then
    printf 'FAIL args=%s workspaces=%s expected cwd=%s\n' "$args" "$workspaces" "$expected"
    exit 1
  fi
}

workspaces="$(jq -cn --arg path "$workspace" '[$path, "/tmp"]')"
for args in '{"Cwd":""}' '{"Cwd":3}' '{}' '{"Cwd":"/dev/null"}' '{"Cwd":"."}' '{"Cwd":"tmp"}'; do
  check_cwd "$args" "$workspaces" "$workspace"
done
check_cwd '{"cWd":"/tmp"}' "$workspaces" /tmp
check_cwd '{}' "$(jq -cn --arg path "$workspace" '[null, "/dev/null", $path]')" "$workspace"
check_cwd '{}' '[false, "/dev/null"]' omitted

# Two Cwd spellings are ambiguous and denied (#3265 review).
t "$(jq -cn '{toolCall:{name:"run_command",args:{CommandLine:"echo hi",Cwd:"/tmp",cwd:"/"}}}')" deny "host guard refuses ambiguous Cwd"
# Array args are not a key map: no command to check, so allow (and no jq error).
t '{"toolCall":{"name":"run_command","args":[1]}}' allow

echo 'ALL PASSED'
