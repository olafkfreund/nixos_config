# shellcheck shell=bash

allow() {
  printf '%s\n' '{"decision":"allow"}'
  exit 0
}

deny() {
  # shellcheck disable=SC2016 # $reason is a jq variable
  @jq@ -cn --arg reason "$1" '{decision:"deny",reason:$reason}'
  exit 0
}

payload="$(cat)" || allow
input="$(printf '%s' "$payload" | @jq@ -ces '
  select(length == 1) | .[0] | objects
  | select(.toolCall.name == "run_command")
  | {
      args: (.toolCall.args | if type == "object" then to_entries else [] end),
      workspaces: (.workspacePaths | arrays // [])
    }
' 2>/dev/null)" || allow

# Normal jq parsing collapses repeated keys, so count their stream events.
# shellcheck disable=SC2016 # $event, $path, and $key are jq variables
key_counts="$(printf '%s' "$payload" | @jq@ --stream -cn '
  reduce inputs as $event ({};
    ($event[0]) as $path
    | if $path[:2] == ["toolCall", "args"] and
        (($event | length) == 2 and ($path | length) == 3 or
         ($event | length) == 1 and ($path | length) == 4)
      then ([$path[2] | strings | ascii_downcase][0]) as $key | if $key then .[$key] += 1 else . end else . end)
')"
if @jq@ -e 'any(keys[]; test("[^\\x00-\\x7f]"))' <<<"$key_counts" >/dev/null; then
  deny "host guard refuses non-ASCII key names"
fi
if @jq@ -e '.commandline > 1' <<<"$key_counts" >/dev/null; then
  deny "host guard refuses ambiguous CommandLine"
fi
# agy keeps the last of duplicate keys, so two Cwd spellings could point the guard at the wrong directory.
if @jq@ -e '.cwd > 1' <<<"$key_counts" >/dev/null; then
  deny "host guard refuses ambiguous Cwd"
fi

translated="$(@jq@ -ce '
  .args[] | select(.key | ascii_downcase == "commandline")
  | .value | strings | {tool_input:{command:.}}
' <<<"$input")" || allow

# shellcheck disable=SC2016 # $counts is a jq variable
while IFS= read -r -d '' directory; do
  if [[ -d "$directory" ]]; then
    translated="$(@jq@ -c --arg cwd "$directory" '. + {cwd:$cwd}' <<<"$translated")"
    break
  fi
done < <(@jq@ -j --argjson counts "$key_counts" '
  (.args[] | select($counts.cwd == 1 and (.key | ascii_downcase == "cwd")) | .value),
  .workspaces[]
  | strings | select(startswith("/") and (contains("\u0000") | not)) | ., "\u0000"
' <<<"$input")

guards=(@guards@)
for guard in "${guards[@]}"; do
  # Keep trailing newlines in the guard's stderr through command substitution.
  message="$(
    "$guard" 2>&1 >/dev/null <<<"$translated"
    status=$?
    printf .
    exit "$status"
  )"
  status=$?
  message="${message%.}"
  case "$status" in
    0) ;;
    2) deny "$message" ;;
    *) deny "host guard ${guard##*/} failed (exit $status): $message" ;;
  esac
done
allow
