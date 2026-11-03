#!/usr/bin/env bash
set -euo pipefail

tool=${1:-}
prompt=${2:-}
reason=''
log=''
head_moved=false
changed='[]'

verdict() {
  jq -cn --argjson ok "$1" --arg tool "$tool" --arg reason "$reason" \
    --argjson changed "$changed" --argjson head_moved "$head_moved" \
    --arg log "$log" '{ok: $ok, tool: $tool, reason: $reason, changed: $changed, head_moved: $head_moved, log: $log}'
}

if [[ ($tool != agy && $tool != codex) || ! -f $prompt ]]; then
  reason='usage: agent-run <agy|codex> <prompt-file>'
  verdict false
  exit 2
fi

if ! root=$(git rev-parse --show-toplevel 2>/dev/null) || ! branch=$(git branch --show-current 2>/dev/null); then
  reason='not a git worktree'
  verdict false
  exit 2
fi
if [[ $(realpath -m -- "$root") == $(realpath -m -- "$HOME/.config/nixos") || $branch == main ]]; then
  reason='refusing shared checkout or main branch'
  verdict false
  exit 2
fi

if [[ -n $(git status --porcelain) ]]; then
  reason='worktree is dirty; commit or discard first'
  verdict false
  exit 2
fi

head=$(git rev-parse HEAD)
log=$(mktemp -t agent-run.XXXXXX.log)
for attempt in 1 2; do
  if [[ $tool == agy ]]; then
    if herdr-run agy agy-implement --output-format json --print-timeout 20m -p "$(cat "$prompt")" >"$log.json" 2>>"$log"; then
      code=0
    else
      code=$?
    fi
  elif herdr-run codex codex-implement exec -o "$log.msg" - <"$prompt" >>"$log" 2>&1; then
    code=0
  else
    code=$?
  fi
  if ((attempt == 1 && code != 0)) && grep -q 'connecting to sandbox server' "$log"; then
    continue
  fi
  break
done
# one log the caller can read: stderr plus the tool's own output
cat "$log.json" "$log.msg" >>"$log" 2>/dev/null || true

changed=$(git status --porcelain -uall | jq -Rsc 'split("\n") | map(select(length > 0) | .[3:])')
if [[ $(git rev-parse HEAD) != "$head" ]]; then
  head_moved=true
fi

if ((code != 0)); then
  reason="tool exited $code"
elif [[ $tool == agy ]] && ! jq -e '.status == "SUCCESS"' "$log.json" >/dev/null 2>&1; then
  reason='agy status is not SUCCESS'
elif [[ $tool == agy ]] && ! jq -e '(.denied_actions | length) == 0' "$log.json" >/dev/null 2>&1; then
  reason='agy denied actions'
elif [[ $tool == agy ]] && ! jq -e '.response | type == "string" and test("\\S")' "$log.json" >/dev/null 2>&1; then
  reason='empty response'
elif [[ $tool == codex ]] && { [[ ! -f $log.msg ]] || [[ -z $(tr -d '[:space:]' <"$log.msg") ]]; }; then
  reason='empty response'
elif [[ $head_moved == true ]]; then
  reason='HEAD moved'
elif [[ $changed == '[]' ]]; then
  reason='empty diff'
fi

if [[ -n $reason ]]; then
  verdict false
  exit 1
fi
verdict true
