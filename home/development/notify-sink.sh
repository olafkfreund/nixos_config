#!/usr/bin/env bash
# Codex notify hook for the herdr team (#2810). argv[1] is the turn payload; stdin is never read.
# Writes the normalized turn file, refuses anything odd, and always exits 0 so it never disturbs the agent.
turns=/run/herdr-team/turns
set -C # the tmp file is created exclusively, never through an existing path

emit() {
  local id out tmp
  id=$(jq -er 'select(.type == "agent-turn-complete") | .["turn-id"] | select(type == "string" and test("^[0-9a-f-]{36}$"))' <<<"${1:-}") || return 1
  [[ -d $turns && ! -L $turns ]] || return 1
  out=$turns/$id.json
  tmp=$turns/.$id.tmp
  [[ ! -e $out && ! -L $out && ! -e $tmp && ! -L $tmp ]] || return 1
  if jq -ce --arg id "$id" '{turn_id: $id, input: .["input-messages"][-1], reply: (.["last-assistant-message"] // ""), source: "codex"}
      | select((.input | type) == "string" and (.reply | type) == "string")' <<<"$1" >"$tmp" && [[ -s $tmp ]]; then
    mv -n -- "$tmp" "$out"
  fi
  rm -f -- "$tmp"
}

emit "${1:-}" 2>/dev/null || true
exit 0
