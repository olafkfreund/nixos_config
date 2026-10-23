#!/usr/bin/env bash
# Run: bash modules/programs/agy-guard-adapter.test.sh   (needs jq on PATH)
# Checks the agy guard adapter (#2087) against agy-shaped payloads, both
# with AGY_CODER=1 (guard active) and without (guard bypassed). Exit 1 on
# any mismatch.
here=$(dirname "$0")
guard=$(mktemp)
crashguard=$(mktemp)
adapter=$(mktemp)
crashadapter=$(mktemp)
trap 'rm -f "$guard" "$crashguard" "$adapter" "$crashadapter"' EXIT
sed 's#@jq@#jq#' "$here/claude-coder-guard.sh" >"$guard"
printf 'exit 1\n' >"$crashguard"
sed -e "s#@jq@#jq#" -e "s#@realpath@#realpath#" -e "s#@guard@#bash $guard#" "$here/agy-guard-adapter.sh" >"$adapter"
sed -e "s#@jq@#jq#" -e "s#@realpath@#realpath#" -e "s#@guard@#bash $crashguard#" "$here/agy-guard-adapter.sh" >"$crashadapter"

fail=0

# A run_command payload with the given shell command as CommandLine.
payload() {
  jq -n --arg c "$1" '{toolCall:{name:"run_command",args:{CommandLine:$c,Cwd:"/tmp"}},conversationId:"t"}'
}

t() {
  # $1 = AGY_CODER value ("" or "1"), $2 = payload json, $3 = want decision
  got="$(printf '%s' "$2" | env AGY_CODER="$1" AGY_WORKTREE=/tmp/wt bash "$adapter" | jq -r .decision)"
  if [ "$got" != "$3" ]; then
    echo "FAIL got=$got want=$3 AGY_CODER=$1: $2"
    fail=1
  fi
}

while IFS= read -r c; do t 1 "$(payload "$c")" deny; done <<'DENY'
git commit -m x
sudo reboot
just quick-deploy p620
DENY

while IFS= read -r c; do t 1 "$(payload "$c")" allow; done <<'ALLOW'
git status
just check-syntax
ALLOW

got="$(echo not json | env AGY_CODER=1 AGY_WORKTREE=/tmp/wt bash "$adapter" | jq -r .decision)"
if [ "$got" != "deny" ]; then
  echo "FAIL got=$got want=deny: not json"
  fail=1
fi

# run_command with no usable CommandLine, or one that isn't a plain string,
# must deny -- previously this fell through to allow.
t 1 "$(jq -n '{toolCall:{name:"run_command",args:{Cwd:"/tmp"}},conversationId:"t"}')" \
  deny # missing CommandLine
t 1 "$(jq -n '{toolCall:{name:"run_command",args:{commandLine:"git status"}}}')" \
  deny # wrong-case key
t 1 "$(jq -n '{toolCall:{name:"run_command",args:{CommandLine:["git","status"]}}}')" \
  deny # CommandLine as an array
t 1 "$(jq -n '{toolCall:{name:"run_command",args:"not-an-object"}}')" \
  deny # args itself a JSON string, not an object

# Non-run_command tools: the safe read/edit surface allows, everything else
# (including agy's other command-running and delegation tools) denies.
t 1 "$(jq -n '{toolCall:{name:"send_command_input",args:{Input:"git commit -m x\n"}}}')" deny
t 1 "$(jq -n '{toolCall:{name:"call_mcp_tool",args:{}}}')" deny
t 1 "$(jq -n '{toolCall:{name:"totally_unknown_tool",args:{}}}')" deny
t 1 "$(jq -n '{toolCall:{name:"view_file",args:{AbsolutePath:"/tmp/x"}}}')" allow
t 1 "$(jq -n '{toolCall:{name:"read_file",args:{Path:"/tmp/wt/a"}}}')" allow
t 1 "$(jq -n '{toolCall:{name:"read_file",args:{Path:"/home/u/.gemini/config/hooks.json"}}}')" deny
t 1 "$(jq -n '{toolCall:{name:"write_to_file",args:{TargetFile:"/tmp/wt/a",CodeContent:"x"}}}')" allow
t 1 "$(jq -n '{toolCall:{name:"write_file",args:{Path:"/tmp/wt/a",Content:"x"}}}')" allow
t 1 "$(jq -n '{toolCall:{name:"edit_file",args:{Path:"/tmp/wt/a",Target:"x",Replacement:"y"}}}')" allow
t 1 "$(jq -n '{toolCall:{name:"write_file",args:{Path:"/tmp/elsewhere/a",Content:"x"}}}')" deny
t 1 "$(jq -n '{toolCall:{name:"edit_file",args:{Path:"/tmp/wt/../elsewhere/a",Target:"x",Replacement:"y"}}}')" deny
t 1 "$(jq -n '{toolCall:{name:"write_file",args:{Content:"x"}}}')" deny
t 1 "$(jq -n '{toolCall:{name:"write_file",args:{Path:"/tmp/wt/.gemini/x",Content:"x"}}}')" deny
t 1 "$(jq -n '{toolCall:{name:"write_to_file",args:{Path:"/tmp/wt/a",TargetFile:"/tmp/out/a",CodeContent:"x"}}}')" deny
t 1 "$(jq -n '{toolCall:{name:"write_to_file",args:{TargetFile:"/tmp/wt/a",targetFile:"/tmp/out/a",CodeContent:"x"}}}')" deny
t 1 "$(jq -n '{toolCall:{name:"write_file",args:{Path:["/tmp/wt/a"],Content:"x"}}}')" deny
t 1 "$(jq -n '{toolCall:{name:"run_command",args:{CommandLine:"ls","bypaſsSandbox":true}}}')" deny
t 1 "$(jq -n '{toolCall:{name:"write_to_file",args:{Path:1,TargetFile:"/tmp/wt/a",CodeContent:"x"}}}')" deny
t 1 "$(jq -n '{toolCall:{name:"write_file",args:{Path:"/tmp/wt/a\n/tmp/wt/b",Content:"x"}}}')" deny
t 1 "$(jq -n '{toolCall:{name:"write_file",args:{Path:"file:///tmp/wt/a",Content:"x"}}}')" allow
t 1 "$(jq -n '{toolCall:{name:"write_file",args:{Path:"a.txt",Content:"x"}}}')" deny
t 1 "$(jq -n '{toolCall:{name:"write_file",args:{Path:"file:///tmp/wt/%2e%2e/%2e%2e/x",Content:"x"}}}')" deny

# No AGY_WORKTREE: a write inside /tmp/wt must still deny.
got="$(jq -n '{toolCall:{name:"write_file",args:{Path:"/tmp/wt/a",Content:"x"}}}' | env -u AGY_WORKTREE AGY_CODER=1 bash "$adapter" | jq -r .decision)"
if [ "$got" != "deny" ]; then
  echo "FAIL got=$got want=deny: write without AGY_WORKTREE"
  fail=1
fi

# Without AGY_CODER, the guard is bypassed regardless of tool or payload.
t "" "$(payload "git commit -m x")" allow
t "" "$(jq -n '{toolCall:{name:"totally_unknown_tool",args:{}}}')" allow

reason="$(payload "git commit -m x" | env AGY_CODER=1 AGY_WORKTREE=/tmp/wt bash "$adapter" | jq -r .reason)"
case "$reason" in
  *"BLOCKED by the coder guard"*) ;;
  *)
    echo "FAIL deny reason missing 'BLOCKED by the coder guard': $reason"
    fail=1
    ;;
esac

got="$(payload "git status" | env AGY_CODER=1 AGY_WORKTREE=/tmp/wt bash "$crashadapter" | jq -r .decision)"
if [ "$got" != "deny" ]; then
  echo "FAIL got=$got want=deny: guard exits 1 (crashed guard fails closed)"
  fail=1
fi

[ "$fail" = 0 ] && echo "agy guard adapter: all cases pass"
exit $fail
