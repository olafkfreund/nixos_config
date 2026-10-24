# shellcheck shell=bash
# PreToolUse hook adapter for agy (#2087). agy's hook payload differs from
# Claude Code's: the command lives at .toolCall.args.CommandLine, not
# .tool_input.command, and a hook must always print exactly one JSON object
# or agy rejects the reply. This adapter translates the payload and hands it
# to the shared coder guard unchanged. The install path is an absolute
# /etc path (not a Nix store path) because hooks.json is carried by
# Syncthing, which cannot follow a store symlink across hosts.
#
# Deny by default (#2087 review): the shared guard only understands shell
# commands, so every agy tool that is not one of the safe read/edit tools
# below is denied outright, and run_command is denied unless its
# CommandLine is actually a string -- an unrecognised tool name, a missing
# CommandLine or a malformed payload all fail closed rather than falling
# through to an allow.

payload="$(cat)"

if [ "${AGY_CODER:-}" != 1 ]; then
  echo '{"decision":"allow"}'
  exit 0
fi

# AGY_GUARD_LOG records "<tool> <decision> <reason>" per call for agy-guard-probe (#2453); a failed write never changes the reply.
# The tool name and reason are flattened so a crafted name cannot forge extra log lines.
log_call() {
  [ -n "${AGY_GUARD_LOG:-}" ] || return 0
  { printf '%s %s %s\n' "$(printf %s "${name:-?}" | tr -c 'A-Za-z0-9_' _)" "$1" "$(printf %s "${2:-}" | tr '\n' ' ')" >>"$AGY_GUARD_LOG"; } 2>/dev/null || true
}

deny() {
  log_call deny "$1"
  # shellcheck disable=SC2016 # $r is a jq variable, not a shell one
  @jq@ -n --arg r "$1" '{decision:"deny",reason:$r}'
  exit 0
}

allow() {
  log_call allow
  echo '{"decision":"allow"}'
  exit 0
}

name="$(echo "$payload" | @jq@ -r '.toolCall.name // empty' 2>/dev/null)"

if ! echo "$payload" | @jq@ -e .toolCall >/dev/null 2>&1; then
  deny "unreadable hook payload"
fi

# agy's own config (settings.json allow rules, hooks.json) is out of bounds for
# a coder session, by any tool, or plain agy could inherit its permissions (#2291).
if echo "$payload" | @jq@ -e '[.toolCall.args | .. | strings] | any(test("\\.gemini"))' >/dev/null 2>&1; then
  deny "agy-implement may not touch ~/.gemini (#2291)"
fi

# Go's EqualFold folds U+017F to s and U+212A to k, so a non-ASCII key could alias a checked one.
# Checked at the root and in toolCall too: Go would read a key argſ as args.
if echo "$payload" | @jq@ -e '[(., .toolCall, .toolCall.args) | objects | keys[] | test("[^\\x00-\\x7f]")] | any' >/dev/null 2>&1; then
  deny "agy-implement refuses non-ASCII key names"
fi

# jq keeps the last of duplicate keys, but Go folds case and merges duplicate objects; count each key's one
# stream event, lowercased, at the root, in toolCall and in args.
# shellcheck disable=SC2016 # $p and $n are jq variables
dups="$(echo "$payload" | @jq@ -c --stream 'def k($p): select(.[0][0:($p|length)]==$p) | ($p|length) as $n | select((length==2 and (.[0]|length)==$n+1) or (length==1 and (.[0]|length)==$n+2)) | "\($p)\(.[0][$n] | strings | ascii_downcase)"; k([]), k(["toolCall"]), k(["toolCall","args"])' | @jq@ -s 'group_by(.) | map(select(length > 1)) | length')"
[ "$dups" = 0 ] || deny "agy-implement refuses duplicate keys"

case "$name" in
  view_file | read_file | grep_search | list_dir | find_by_name | ask_question | list_permissions)
    allow
    ;;
  # --sandbox confines shell commands only, so file writes are fenced here to
  # the directory agy-implement started in. Hooks run in ~/.gemini/config, so
  # the wrapper passes that directory as AGY_WORKTREE (#2296).
  write_to_file | replace_file_content | multi_replace_file_content | write_file | edit_file)
    [ -n "${AGY_WORKTREE:-}" ] || deny "AGY_WORKTREE is not set"
    # Every Path/TargetFile arg must be inside: agy decodes keys case-insensitively
    # and may write either one, so checking only the first would be a bypass.
    # Any other string arg named like a path could be a second write target.
    if echo "$payload" | @jq@ -e '[.toolCall.args | to_entries[] | select((.value|type)=="string") | .key | ascii_downcase | select(test("path|file")) | select(. != "path" and . != "targetfile")] | length > 0' >/dev/null 2>&1; then
      deny "agy-implement refuses unknown path argument on $name"
    fi
    targets="$(echo "$payload" | @jq@ -r '[.toolCall.args | to_entries[] | select(.key | ascii_downcase | . == "path" or . == "targetfile") | .value] | if length == 0 or any(.[]; type != "string" or . == "" or test("\n")) then empty else .[] | sub("^file://"; "") end')"
    [ -n "$targets" ] || deny "$name without a path"
    wt="$(@realpath@ -m -- "$AGY_WORKTREE")"
    [ -n "$wt" ] || deny "cannot resolve AGY_WORKTREE"
    while IFS= read -r target; do
      # A relative or %-encoded path resolves differently for agy than for realpath.
      case "$target" in
        *%*) deny "agy-implement needs an absolute, unencoded path" ;;
        /*) ;;
        *) deny "agy-implement needs an absolute, unencoded path" ;;
      esac
      # shortcut: a parallel run_command can swap in a symlink after this check; only --sandbox closes that (#2453).
      resolved="$(@realpath@ -m -- "$target")"
      case "$resolved/" in
        "$wt"/*) ;;
        *) deny "agy-implement may only write inside $AGY_WORKTREE (#2296)" ;;
      esac
      # These paths run code outside the sandbox (hooks, direnv, pre-commit, devenv).
      rel="${resolved#"$wt"/}"
      case "/$rel/" in
        */.git/* | */.claude/* | */.envrc/* | */.direnv/* | */.githooks/*)
          deny "agy-implement may not write $rel: it runs code outside the sandbox (#2453)"
          ;;
      esac
      case "${rel##*/}" in
        .pre-commit-config.yaml | devenv.nix)
          deny "agy-implement may not write $rel: it runs code outside the sandbox (#2453)"
          ;;
      esac
      # A hard link would write through to a file outside the worktree.
      if [ -e "$resolved" ] && [ ! -d "$resolved" ] && [ "$(@stat@ -c %h -- "$resolved" 2>/dev/null)" != 1 ]; then
        deny "agy-implement refuses a hard-linked target (#2453)"
      fi
    done <<<"$targets"
    allow
    ;;
  run_command)
    if ! echo "$payload" | @jq@ -e '.toolCall.args.CommandLine | strings' >/dev/null 2>&1; then
      deny "run_command without a string CommandLine"
    fi
    # agy decodes args with Go's case-insensitive JSON, so match any casing (#2298).
    if echo "$payload" | @jq@ -e '[.toolCall.args | to_entries[] | select(.key | ascii_downcase == "bypasssandbox") | .value] | any(. != false and . != null)' >/dev/null 2>&1; then
      deny "agy-implement may not bypass the sandbox (#2298)"
    fi
    cmd="$(echo "$payload" | @jq@ -r '.toolCall.args.CommandLine')"

    # shellcheck disable=SC2016 # $c is a jq variable, not a shell one
    msg=$(@jq@ -n --arg c "$cmd" '{tool_input:{command:$c}}' | @guard@ 2>&1 >/dev/null)
    code=$?

    if [ "$code" = 0 ]; then
      allow
    elif [ "$code" = 2 ]; then
      deny "$msg"
    else
      deny "coder guard failed (exit $code): $msg"
    fi
    ;;
  *)
    deny "tool ${name:-<missing>} is not allowed under agy-implement"
    ;;
esac
